(ns flow-profiler
  (:use [clojure.contrib.string :only [split split-lines]]
        [clojure.contrib.str-utils :only [str-join]]
        [clojure.contrib.math :only [round]]
        [clojure.contrib.def])
  (:require [clojure.contrib.duck-streams :as ds])
  (:import (java.io InputStream FileInputStream BufferedInputStream EOFException)
           (java.nio ByteBuffer ByteOrder)
           (java.awt Font)
           (javax.swing.tree TreeModel)
           (javax.swing JPanel JTree JScrollPane JFrame JPopupMenu JMenuItem)
           (java.awt.event MouseAdapter ActionListener)))

;;; Data input

(defn load-debug-info
  "Parse the debug info file into maps of functions and line numbers."
  [fname]
  (reduce (fn [[func-range-map fn-map loc-map :as cur-state] file-line]
            (or (if-let [[_ pc file line] (re-matches #"^(\d+)\s+(\S+)\s+(\d+).*" file-line)]
                  (let [ipc (Integer. pc)]
                    [func-range-map
                     (if (= file "--end--")
                       (assoc fn-map ipc :native)
                       fn-map)
                     (assoc loc-map ipc
                       {:file file :line (Integer. line)})]))
                (if-let [[_ pc function] (re-matches #"^(\d+)\s+(\S+).*" file-line)]
                  (let [ipc (Integer. pc)]
                    [(assoc func-range-map function
                            (conj (get func-range-map function []) ipc))
                     (assoc fn-map ipc function)
                     loc-map]))
                cur-state))
          [(hash-map) (sorted-map) (sorted-map)]
          (ds/read-lines fname)))

(defn range-lookup [smap address]
  (first (rsubseq smap <= address)))

(defn- range-lookup-fun [smap]
  (memoize #(range-lookup smap %)))

(defn load-profile-data
  "Load the binary profile data file into a clojure array."
  [fname]
  (with-open [fstream (FileInputStream. fname)]
    ;; Use java.nio for speed:
    (let [fchannel (.getChannel fstream)
          hbuffer (ByteBuffer/allocate 8)]
      (.order hbuffer ByteOrder/LITTLE_ENDIAN)
      (.read fchannel hbuffer)
      (when (or (not= (.getInt hbuffer 0) 0x574f4c46)
                (not= (.getInt hbuffer 4) 0x464f5250))
        (throw (Exception. "Invalid profile data format")))
      (loop [event-list []]
        (.clear hbuffer)
        (if (= (.read fchannel hbuffer) 8)
          (let [samples (.getInt hbuffer 0)
                depth (.getInt hbuffer 4)
                size (* 4 depth)
                buffer (ByteBuffer/allocate size)]
            (.order buffer ByteOrder/LITTLE_ENDIAN)
            (if (= (.read fchannel buffer) size)
              (let [stack (int-array depth)]
                (.rewind buffer)
                (.get (.asIntBuffer buffer) stack)
                (recur (conj event-list
                             {:samples samples
                              :stack (into [] stack)})))
              ;; bail out on eof:
              event-list))
          event-list)))))

(defn make-profile-info [[fpos-map fn-map loc-map] profile-data]
  {:fpos-map fpos-map
   :fn-map fn-map
   :loc-map loc-map
   :profile-data profile-data
   :fn-lookup (memoize #(if (< % 0)
                          (if (= (bit-and % 0x70000000) 0)
                              [% {:type :impersonate-ctx :ptr (bit-and % 0xFFFFFFF)}]
                              [% {:type :special-ctx :id (- -1 %)}])
                          (range-lookup fn-map %)))})

(defn find-function-location [{fpos-map :fpos-map loc-map :loc-map} fname]
  (let [fposlist (get fpos-map fname)]
    (second (range-lookup loc-map (first fposlist)))))

(defn find-function-and-location [{fn-map :fn-map loc-map :loc-map} faddr]
  [(second (range-lookup fn-map faddr)) (second (range-lookup loc-map faddr))])

;;; Tab-separated output

(defn print-tab-separated [data]
  (doseq [row data]
    (print (first row))
    (doseq [item (rest row)]
      (print "\t")
      (print item))
    (print "\n")))

;;; Trivial reports

(defn- aggregate-line-numbers [line-seq]
  (reduce (fn [old-map {file :file line :line}]
            (let [filedata (or (get old-map file) (hash-map))
                  linecount (get filedata line 0)]
              (assoc old-map file (assoc filedata line (+ linecount 1)))))
          (hash-map)
          line-seq))

(defn compute-total-lines [{loc-map :loc-map}]
  (aggregate-line-numbers (map second loc-map)))

(defn compute-covered-lines [{loc-map :loc-map profile-data :profile-data}]
  (aggregate-line-numbers (map (fn [{samples :samples stack :stack}]
                                 (let [current-cp (nth stack 0)]
                                   (second (range-lookup loc-map current-cp))))
                               profile-data)))

(defn compute-self-rating [{fn-lookup :fn-lookup profile-data :profile-data
                            :as info}]
  (let [rating
        (reduce (fn [old-map {samples :samples stack :stack}]
                  (let [current-cp (nth stack 0)
                        func (second (fn-lookup current-cp))]
                    (assoc old-map func
                           (+ (get old-map func 0) samples))))
                (hash-map)
                profile-data)]
    (sort-by #(- (second %))
             (for [[fname cnt] rating]
               (let [loc (find-function-location info fname)]
                 [fname cnt
                  (or (:file loc) "")
                  (or (:line loc) -1)])))))

(defn compute-coverage-stats [info]
  (let [total-lines (compute-total-lines info)
        covered-lines (compute-covered-lines info)]
    (sort-by (fn [x] [(- (nth x 2)) (nth x 3)])
             (map (fn [[file linfo]]
                    (let [linfo2 (get covered-lines file)
                          count1 (count linfo)
                          count2 (if linfo2 (count linfo2) 0)]
                      [count1 count2 (int (/ (* count2 100.0) count1)) file]))
                  total-lines))))

(defn annotate-line-samples [info fname]
  (let [total-lines (compute-total-lines info)
        covered-lines (compute-covered-lines info)
        file-info-total (get total-lines fname)
        file-info-hit (or (get covered-lines fname) (hash-map))]
    (if file-info-total
      (map-indexed (fn [idx line]
                     (let [lid (+ idx 1)
                           hit (get file-info-hit lid 0)
                           total (get file-info-total lid 0)]
                       [(cond
                         (> hit 0) hit
                         (> total 0) "-"
                         true "")
                        line]))
                   (ds/read-lines fname))
      [])))

;;; Prefiltered profile data

(defn prepare-profile [debug-info profile-data]
  (let [info (make-profile-info debug-info profile-data)
        fn-lookup (:fn-lookup info)
        fn-stack-map
        (reduce (fn [old-map {samples :samples stack :stack}]
                  (let [func-stack (into [] (map #(second (fn-lookup %)) stack))]
                    (assoc old-map func-stack
                           (+ (get old-map func-stack 0) samples))))
                (hash-map)
                profile-data)]
    (assoc info
      :fn-stack-map fn-stack-map
      :total-samples (reduce + (vals fn-stack-map)))))

(defn filter-profile [profile-data stacks reverse? remove?]
  (let [lens (reduce conj #{} (map count stacks))
        matchf (if remove? nil? #(not (nil? %)))
        ffun (if reverse?
               (fn [[stack samples]]
                 (matchf (some #(get stacks (into [] (reverse (take % stack)))) lens)))
               (fn [[stack samples]]
                 (matchf (some #(get stacks (into [] (take-last % stack))) lens))))
        new-map (into (hash-map) (filter ffun (get profile-data :fn-stack-map)))]
    (assoc profile-data
      :fn-stack-map new-map
      :total-samples (reduce + (vals new-map)))))

;;; Tree node identity information

(defn- identity-type [identity]
  (cond (string? identity) 'string
        (map? identity) (:type identity)
        true identity))

(defmulti describe-identity
  (fn [_ identity] (identity-type identity)))

(defmethod describe-identity 'string [_ str] str)
(defmethod describe-identity :root [_ _] "<root>")
(defmethod describe-identity :children [_ _] "<all callees>")
(defmethod describe-identity :native [_ _] "<native code>")
(defmethod describe-identity :unknown [_ _] "<unknown code>")

(defmethod describe-identity :special-ctx [_ fn-info]
  (str "<special " (:id fn-info) ">"))

(defmethod describe-identity :function [profile-info fn-info]
  (let [fname (:name fn-info)
        loc-info (find-function-location profile-info fname)]
    (if loc-info
      (str fname " @ " (:file loc-info) ":" (:line loc-info))
      fname)))

(defmethod describe-identity :impersonate-ctx [profile-info fn-info]
  (let [[fname loc-info] (find-function-and-location profile-info (:ptr fn-info))
        locstr (if loc-info
                 (str " @ " (:file loc-info) ":" (:line loc-info))
                 "")]
    (str "FOR " (or fname "<unknown>") locstr)))

(defn function-identity [fname]
  (cond (nil? fname)     :unknown
        (keyword? fname) fname
        (map? fname)     fname
        true
        {:type :function :name fname}))

(defn- function-from-identity [id]
  (cond (= (identity-type id) :function) (:name id)
        (= id :unknown)                  nil
        true id))

;;; Call tree construction

(defn- make-call-tree-node [identity & [stacks?]]
  {:identity identity
   :samples 0 :self-samples 0 :stacks (if stacks? #{} nil)
   :children (hash-map)})

(defn- make-stack-filter [node path]
  (if-let [stacks (:stacks node)]
    (into #{}
          (map #(into [] (take-last (- (count (second %)) (first %)) (second %))) stacks))
    #{(into []
            (map #(function-from-identity (:identity %))
                 (filter #(get #{:function :native :special-ctx :impersonate-ctx}
                               (identity-type (:identity %)))
                         (reverse (conj path node)))))}))

(defn- walk-call-tree-rec
  "Integrate the sample into the tree, using given identity function."
  ([cur-tree identity-lookup samples stack fullstack idx]
   (if (< idx 0)
     (assoc cur-tree
       :stacks (if-let [cur-stacks (get cur-tree :stacks)]
                 (conj cur-stacks [0 fullstack])
                 nil)
       :samples (+ (get cur-tree :samples) samples)
       :self-samples (+ (get cur-tree :self-samples) samples))
     (let [identity (identity-lookup stack idx)
           cur-children (get cur-tree :children)
           cur-stacks (get cur-tree :stacks)
           child (or (get cur-children identity)
                     (make-call-tree-node identity cur-stacks))]
       (assoc cur-tree
         :stacks (if cur-stacks
                   (conj cur-stacks [(inc idx) fullstack])
                   nil)
         :samples (+ (get cur-tree :samples) samples)
         :children (assoc cur-children identity
                          (walk-call-tree-rec child identity-lookup samples stack fullstack (dec idx))))))))

(defn walk-call-tree
  "Integrate the sample into the tree, using given identity function."
  ([cur-tree identity-lookup samples stack]
   (walk-call-tree-rec cur-tree identity-lookup samples stack stack (dec (count stack))))
  ([cur-tree identity-lookup samples stack fullstack]
   (walk-call-tree-rec cur-tree identity-lookup samples stack fullstack (dec (count stack)))))

(defn- function-identity-fn [stack idx]
  (function-identity (nth stack idx)))

(defn aggregate-call-tree [prepared-data]
  "Aggregates the samples into a global call tree by function."
  (reduce #(walk-call-tree %1 function-identity-fn (second %2) (first %2))
          (make-call-tree-node :root)
          (:fn-stack-map prepared-data)))

(defn aggregate-function [prepared-data function callers?]
  "Builds a filtered tree of all non-recursive callees of the function."
  (reduce (fn [tree [stack samples]]
            (let [functions (if callers? (into [] (reverse stack)) stack)]
              (if (some #(= % function) functions)
                (walk-call-tree tree function-identity-fn samples
                                (take-while #(not= % function) functions)
                                functions)
                tree)))
          (make-call-tree-node (function-identity function) true)
          (:fn-stack-map prepared-data)))

(defn aggregate-cumulative [prepared-data]
  "Builds a flat list of all functions with cumulative sampling."
  (reduce (fn [tree [stack samples]]
            (let [cur-fun (nth stack 0)
                  func-set (disj (into #{} stack) :native)]
              (assoc
                  (reduce (fn [tree function]
                            (walk-call-tree tree function-identity-fn samples
                                            (if (= function cur-fun)
                                              [function]
                                              [:children function])))
                          tree func-set)
                ;; Patch the root sample count
                :samples (+ (:samples tree) samples))))
          (make-call-tree-node :root true)
          (:fn-stack-map prepared-data)))

(defn aggregate-self [prepared-data]
  "Builds a flat list of all functions, using only self data."
  (reduce (fn [tree [stack samples]]
            (let [cur-fun (nth stack 0)]
              (walk-call-tree tree function-identity-fn samples [cur-fun])))
          (make-call-tree-node :root true)
          (:fn-stack-map prepared-data)))

;;; Abstract GUI tree presentation

(defprotocol AnyTreeNode
  (children [t])
  (is-leaf [t])
  (popup-commands [t])
  (toString [t]))

(defn- index-in-seq [lst item]
  (loop [i 0
         s (seq lst)]
    (cond (empty? s) -1
          (= (first s) item) i
          true (recur (inc i) (rest s)))))

(defn- any-tree-model [root-node]
  (proxy [TreeModel] []
    (getRoot [] root-node)
    (addTreeModelListener [treeModelListener])
    (getChild [parent index]
      (nth (children parent) index))
    (getChildCount [parent]
      (count (children parent)))
    (isLeaf [node]
      (is-leaf node))
    (valueForPathChanged [path newValue])
    (getIndexOfChild [parent child]
      (index-in-seq (children parent) child))
    (removeTreeModelListener [treeModelListener])))

(defn- try-show-popup [tree event]
  (if-let [path (.getPathForLocation tree (.getX event) (.getY event))]
    (do
      (.setSelectionPath tree path)
      (if-let [node (.getLastPathComponent path)]
        (let [popups (popup-commands node)]
          (when (> (count popups) 0)
            (let [menu (JPopupMenu.)]
              (doseq [[name cb] popups]
                (let [item (JMenuItem. name)
                      listener (proxy [ActionListener] []
                                 (actionPerformed [event]
                                   (cb)))]
                  (.addActionListener item listener)
                  (.add menu item)))
              (.show menu tree (.getX event) (.getY event)))))))))

(defn- any-tree [root-node]
  (let [tree (JTree. (any-tree-model root-node))
        fontsize (System/getenv "FLOWPROF_FONTSIZE")
        mcb (proxy [MouseAdapter] []
              (mousePressed [event]
                (when (.isPopupTrigger event)
                  (try-show-popup tree event)))
              (mouseReleased [event]
                (when (.isPopupTrigger event)
                  (try-show-popup tree event))))]
    (.addMouseListener tree mcb)
    (if (not= fontsize nil) 
        (.setFont tree (Font. "monospaced" (. Font PLAIN) (Integer/parseInt fontsize)))
        ())
    tree))

;;; Call tree presentation

(deftype LazyTreeNode [name children popups]
  AnyTreeNode
  (toString [this] name)
  (is-leaf [this]
    (and (not (delay? children)) (empty? children)))
  (children [this]
    (if (delay? children) @children children))
  (popup-commands [this]
    popups))

(defn- percent [value total & [step]]
  (str (.format (java.text.DecimalFormat. "#0.0%") (if (not= total 0) (/ value total) -1))
       " = " (int (/ value (or step 1)))))

(defn- wrap-tree-element [context node path]
  (let [idspec (describe-identity (:prepared-data context) (:identity node))
        total-samples (:total-samples context)
        sample-step (:sample-step context)
        sspec  (percent (:samples node) total-samples sample-step)
        ssspec (if (>= (:self-samples node) (:min-self-size context))
                 (str " (self " (percent (:self-samples node) total-samples sample-step) ")")
                 "")
        child-map (:children node)]
    (LazyTreeNode. (str sspec ssspec ": " idspec)
                   (if (empty? child-map) []
                       (delay
                        (map #(wrap-tree-element context % (conj path node))
                             (sort-by #(- (:samples %)) (vals child-map)))))
                   (if-let [cb (:menu-cb context)]
                     (cb node path context)))))

(defn- call-tree-model [debug-info call-tree]
  (any-tree-model
   (wrap-tree-element debug-info (:samples call-tree) call-tree [])))

(defn browse-call-tree
  [prepared-data call-tree & flags]
  (let [context (into {:prepared-data prepared-data
                       :total-samples (:samples call-tree)
                       :min-self-size (/ (:samples call-tree) 1000)
                       :sample-step 1000 :reverse-stack? false}
                      (apply hash-map flags))]
    (doto (JFrame. (or (:title context) "Call Tree"))
      (.add (JScrollPane. (any-tree (wrap-tree-element context call-tree []))))
      (.setSize 800 600)
      (.setVisible true))))

(defnk browse-profile-info [prepared-data :sample-step 1000 :title "Global Call Tree"]
  (let [base-tree (aggregate-call-tree prepared-data)
        total-samples (:total-samples prepared-data)]
    (letfn [(show-tree [title data & flags]
              (apply browse-call-tree prepared-data data
                     :title title :menu-cb menu-cb
                     :sample-step sample-step
                     flags))
            (menu-cb [node path context]
              (let [id (:identity node)]
                (cond
                 ;; Root node
                 (= (identity-type id) :root)
                 [["Cumulative Rating"
                   (fn []
                     (show-tree "Flat rating of functions"
                                (aggregate-cumulative prepared-data)
                                :reverse-stack? true))]
                  ["Self Rating"
                   (fn []
                     (show-tree "Flat rating of functions (self)"
                                (aggregate-self prepared-data)
                                :reverse-stack? true))]]
                 ;; Function nodes
                 (get #{:function :special-ctx :impersonate-ctx} (identity-type id))
                 [["Aggregate Callees (functions called by this)"
                   (fn []
                     (show-tree (str "Functions called by " (describe-identity prepared-data id))
                                (aggregate-function prepared-data (function-from-identity id) false)
                                :total-samples total-samples))]
                  ["Aggregate Callers of this"
                   (fn []
                     (show-tree (str "Callers of " (describe-identity prepared-data id))
                                (aggregate-function prepared-data (function-from-identity id) true)
                                :min-self-size total-samples
                                :total-samples total-samples
                                :reverse-stack? true))]
                  ["Global Filter: Only This Subtree"
                   (fn []
                     (browse-profile-info (filter-profile prepared-data (make-stack-filter node path)
                                                          (:reverse-stack? context) false)
                                          :sample-step sample-step :title "Filtered Call Tree"))]
                  ["Global Filter: Remove This Subtree"
                   (fn []
                     (browse-profile-info (filter-profile prepared-data (make-stack-filter node path)
                                                          (:reverse-stack? context) true)
                                          :sample-step sample-step :title "Filtered Call Tree"))]])))]
      (show-tree title base-tree))))

