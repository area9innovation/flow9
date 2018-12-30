(ns debug-server
  (:use [clojure.contrib.string :only [split split-lines]]
        [clojure.contrib.str-utils :only [str-join]]
        [clojure.contrib.def])
  (:require [clojure.contrib.server-socket :as ss]
            [clojure.xml :as xml]
            [clojure.contrib.prxml :as pxml])
  (:import (java.io InputStreamReader OutputStream OutputStreamWriter BufferedReader
                    ByteArrayInputStream)))

(defn- read-nt-line [^java.io.Reader rdr]
  (let [sb (StringBuffer.)]
    (loop [c (.read rdr)]
      (if (<= c 0)
        (let [s (.toString sb)]
          (if (and (< c 0)
                   (= (.length s) 0))
            nil
            s))
        (do
          (.append sb (char c))
          (recur (.read rdr)))))))

(defn- parse-xml [xstr]
  (let [input-stream (ByteArrayInputStream. (.getBytes xstr "UTF-8"))]
    (xml/parse input-stream)))

(defn- make-xml [& data]
  (with-out-str
    (apply pxml/prxml data)))

(def *policy-file*
     (str "<?xml version=\"1.0\"?>"
          "<!DOCTYPE cross-domain-policy SYSTEM \"http://www.macromedia.com/xml/dtds/cross-domain-policy.dtd\">"
          "<cross-domain-policy>"
          "<allow-access-from domain=\"*\" to-ports=\"17777\"/>" 
          "</cross-domain-policy>\000"))

(defn- validate-link-struct [link]
  (and (integer? (:id link))
       (integer? (:last-cmd link))
       (integer? (:last-answered link))
       (map? (:active-cmds link))))

(defn- call-hook [callback agent id args]
  (try
   (apply callback agent id args)
   (catch Exception e
     (println "Hook" id "failed:" e))))

(defn- send-command-inner [link retval attrs]
  (try
   (let [cmdid (inc (:last-cmd link))
         cmds (:active-cmds link)
         nlink (assoc link
                 :last-cmd cmdid
                 :active-cmds (assoc cmds cmdid
                                     {:id cmdid :args attrs :rv retval}))
         xml (make-xml [:command (assoc attrs :id cmdid)])
         out (:output link)]
     (when (nil? out)
       (throw (Exception. "Link already closed.")))
     (.write out xml)
     (.write out "\000")
     (.flush out)
     nlink)
   (catch Exception e
     (binding [*out* (:log link)]
       (println "Couldn't send command: " attrs
                " due to error: " e))
     (deliver retval nil)
     link)))

(defn- finalize-cmd [link id result]
  (let [nxans (inc (:last-answered link))]
    (if (< nxans id)
      ;; Wipe skipped commands
      (recur (finalize-cmd link nxans nil) id result)
      ;; Deliver the result and forget the command:
      (let [acmd (:active-cmds link)
            rv (:rv (get acmd id))]
        (when rv
          (deliver rv result))
        (assoc link :last-answered id :active-cmds (dissoc acmd id))))))

(defn- handle-message [link message-str]
  (binding [*out* (:log link)]
    (let [xml (parse-xml message-str)
          tag (:tag xml)]
      (cond (= tag :command-error)
            (let [id (Integer/parseInt (:id (:attrs xml)))
                  text (apply str (:content xml))
                  cmd (get (:active-cmds link) id)]
              (println "Command failed:" (:args cmd) " Error:" text)
              (finalize-cmd link id nil))
            (= tag :command-reply)
            (let [id (Integer/parseInt (:id (:attrs xml)))]
              (finalize-cmd link id xml))
            (= tag :event)
            (let [type (:type (:attrs xml))
                  text (:text (:attrs xml))
                  ehist (:event-history link)]
              (when text
                (println "Event:" type " Msg:" text))
              (doseq [[id cb] (seq (:event-hooks link))]
                (call-hook cb (:agent link) id [type xml]))
              (if text
                (assoc link :event-history (conj ehist xml))
                link))
            true
            (do
              (println "Message:" message-str)
              link)))))

(defn- assoc-hook [link table id hook]
  (assoc link table
         (if hook
           (assoc (get link table) id hook)
           (dissoc (get link table) id))))

(defn- set-event-hook-inner [link id hook process-history?]
  (binding [*out* (:log link)]
    (when (and hook process-history?)
      (doseq [xml (:event-history link)]
        (call-hook hook (:agent link) id [(:type (:attrs xml)) xml])))
    (assoc-hook link :event-hooks id hook)))

(defnk set-event-hook [agent id hook :process-history? false]
  (send agent set-event-hook-inner id hook process-history?))

(defn set-disconnect-hook [agent id hook]
  (send agent assoc-hook :disconnect-hooks id hook))

(defonce *active-links* (atom {}))

(defn- handle-eof [link notifier]
  (binding [*out* (:log link)]
    (println "Runner disconnected.")
    (doseq [[id cb] (seq (:disconnect-hooks link))]
      (call-hook cb (:agent link) id [])))
  (deliver notifier nil)
  (swap! *active-links* dissoc (:id link))
  (let [link (finalize-cmd link (:last-cmd link) nil)]
    (assoc link :input nil :output nil)))

(defonce *connect-hooks* (atom {}))

(defn set-connect-hook [id hook]
  (if hook
    (swap! *connect-hooks* assoc id hook)
    (swap! *connect-hooks* dissoc id)))

(defn- handle-connect [link agent]
  (binding [*out* (:log link)]
    (println "Runner connected.")
    (swap! *active-links* assoc (:id link) agent)
    (doseq [[id cb] (seq @*connect-hooks*)]
      (call-hook cb agent id [])))
  (send-command-inner (assoc link :agent agent)
                      (promise)
                      {:name "init-link" :link-id (:id link)}))

(defn- handle-agent-exception [agent exception]
  (binding [*out* (:log @agent)]
    (println "Crash in agent: " exception)))


(defn send-command [l-agent cmd-name & cmd-attrs]
  (let [retval (promise)
        attrs (assoc (apply hash-map cmd-attrs) :name (name cmd-name))]
    (send l-agent send-command-inner retval attrs)
    retval))

(defonce *id-counter* (atom 0))

(defn- debug-repl [ins outs log]
  (let [input (BufferedReader. (InputStreamReader. ins))
        output (OutputStreamWriter. outs)]
    (loop [i-agent nil]
      (try
       (let [cmd (read-nt-line input)]
         (cond (nil? cmd)
               (do
                 (when i-agent
                   (let [notifier (promise)]
                     (send i-agent handle-eof notifier)
                     (deref notifier))))
               ;; Agent mode
               i-agent
               (do
                 (send i-agent handle-message cmd)
                 (recur i-agent))
               ;; Policy request?
               (= cmd "<policy-file-request/>")
               (do
                 (.write output *policy-file*)
                 (.flush output)
                 (recur i-agent))
               ;; Handshake?
               (= cmd "<runner-connect/>")
               (let [i-agent (agent {:input input :output output :log log
                                     :id (swap! *id-counter* inc)
                                     :last-cmd 0 :last-answered 0
                                     :active-cmds {} :event-history []
                                     :disconnect-hooks {} :event-hooks {}})]
                 (set-error-handler! i-agent handle-agent-exception)
                 (set-error-mode! i-agent :continue)
                 (set-validator! i-agent validate-link-struct)
                 (send i-agent handle-connect i-agent)
                 (recur i-agent))
               ;; otherwise
               true
               (do
                 (.write output "<invalid/>\000")
                 (.flush output)
                 (recur i-agent))))
       (catch Exception e
         (when i-agent
           (send i-agent handle-eof (promise))))))))

(defonce *server*
  (let [out *out*]
    (ss/create-server 17777 (fn [i o] (debug-repl i o out)))))

(defn get-link [& [link]]
  (let [links @*active-links*
        agent (cond (nil? link)
                    (get links (reduce max 0 (keys links)))
                    (integer? link)
                    (get links link)
                    true link)]
    agent))

(defn event-history [& [link]]
  (let [agent (get-link link)]
    (or (when agent
          (:event-history @agent))
        [])))

(defn evh [] (event-history))
