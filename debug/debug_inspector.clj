(ns debug-inspector
  (:use [debug-server]
        [clojure.contrib.string :only [split split-lines]]
        [clojure.contrib.str-utils :only [str-join]]
        [clojure.contrib.seq-utils :only [find-first]]
        [clojure.contrib.def])
;  (:require )
  (:import (java.awt BorderLayout)
           (java.awt.event ActionEvent ActionListener)
           (javax.swing.tree TreeModel)
           (javax.swing.table TableModel AbstractTableModel)
           (javax.swing JPanel JTree JTable JScrollPane JFrame JToolBar JButton SwingUtilities)))

(defn- index-in-seq [lst item]
  (loop [i 0
         s (seq lst)]
    (cond (empty? s) -1
          (= (first s) item) i
          true (recur (inc i) (rest s)))))

(defprotocol XMLTreeNode
  (children [t])
  (is-leaf [t])
  (toString [t]))

(deftype BasicXMLTreeNode [name children]
  XMLTreeNode
  (toString [this] name)
  (is-leaf [this]
    (and (not (delay? children)) (empty? children)))
  (children [this]
    (if (delay? children) @children children)))

(defmulti wrap-xml-element
  (fn [foo]
    (if (string? foo) 'string (:tag foo))))

(defn- clip-string [astring size]
  (if (> (count astring) size)
    (str (subs astring 0 size) "...")
    astring))

(defn- make-attr-node [aname value]
  (BasicXMLTreeNode. (str (name aname) " = " value) []))

(defmethod wrap-xml-element 'string [str]
  (BasicXMLTreeNode. str []))

(defmethod wrap-xml-element :default [elt]
  (let [tag (:tag elt)
        attrs (:attrs elt)
        content (:content elt)
        anames (sort (keys attrs))
        has-attrs? (not (empty? anames))
        astring (str-join " "
                          (map (fn [aname]
                                 (str (name aname) "=\"" (get attrs aname) "\""))
                               anames))
        name (str "<" (name tag)
                  (if has-attrs? (str " " (clip-string astring 100)) "")
                  ">")
        needs-attr-node? (and has-attrs? (> (count astring) 100))
        children
        (when (or needs-attr-node? (not (empty? content)))
          (delay
           (into []
                 (filter #(not (nil? %))
                         (concat [(when needs-attr-node?
                                    (BasicXMLTreeNode.
                                     "-Attributes-" (delay (map #(make-attr-node % (get attrs %)) anames))))]
                                 (map wrap-xml-element content))))))]
    (BasicXMLTreeNode. name children)))

(defn- xml-tree-model [data]
  (proxy [TreeModel] []
    (getRoot [] (wrap-xml-element data))
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

(defn inspect-xml-tree
  "creates a graphical (Swing) inspector on the supplied xml data tree"
  [data]
  (doto (JFrame. "XML Inspector")
    (.add (JScrollPane. (JTree. (xml-tree-model data))))
    (.setSize 800 600)
    (.setVisible true)))

(defn enable-xml-inspector []
  (set-connect-hook :inspect-tree
                    (fn [agent id]
                      (set-event-hook agent id (fn [agent id type xml]
                                                 (inspect-xml-tree xml))))))

#_
(enable-xml-inspector)
