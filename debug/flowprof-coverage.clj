(use 'flow-profiler)

(when (< (count *command-line-args*) 2)
  (println "Usage: flowprof-coverage <profile-data-file> <debug-info-file> [fname]")
  (System/exit 1))

(let [[data-fn debug-fn text-fn] *command-line-args*
      debug-info (load-debug-info debug-fn)
      profile-data (load-profile-data data-fn)
      info (make-profile-info debug-info profile-data)]
  (print-tab-separated (if text-fn
                         (annotate-line-samples info text-fn)
                         (compute-coverage-stats info))))
