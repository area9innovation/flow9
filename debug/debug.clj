;;; Main file of the debug listener.
;;;
;;; Run as: clj.bat debug.clj
;;;
;;; Requires java in the PATH, and clojure JARs in the current dir.
;;;
;;; Usage:
;;; 1. Compile FlowFlash with debug_flow enabled.
;;; 2. Start this script
;;; 3. Every time an error happens, a window with info will pop up.

(use 'debug-inspector)

(debug-inspector/enable-xml-inspector)

(println "Waiting for connections...")
