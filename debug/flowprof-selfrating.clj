(use 'flow-profiler)

(when (< (count *command-line-args*) 2)
  (println "Usage: flowprof-selfrating <profile-data-file> <debug-info-file>")
  (System/exit 1))

(let [debug-info (load-debug-info (second *command-line-args*))
      profile-data (load-profile-data (first *command-line-args*))
      info (make-profile-info debug-info profile-data)]
  (print-tab-separated (compute-self-rating info)))
