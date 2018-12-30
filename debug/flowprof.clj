(use 'flow-profiler)

(when (< (count *command-line-args*) 2)
  (println "Usage: flowprof <profile-data-file> <debug-info-file> [sample-divisor]")
  (System/exit 1))

(let [[data-fn debug-fn sample-step] *command-line-args*
      sstep (if sample-step (Integer/parseInt sample-step) 1000)
      debug-info (flow-profiler/load-debug-info debug-fn)
      profile-data (flow-profiler/load-profile-data data-fn)
      prepared-data (flow-profiler/prepare-profile debug-info profile-data)
      _ (println "Loaded" (count profile-data)
                 "records of total" (:total-samples prepared-data) "samples.")
      _ (println "Sample display divisor:" sstep)
      frame (flow-profiler/browse-profile-info prepared-data :sample-step sstep)]
  (.setDefaultCloseOperation frame javax.swing.JFrame/EXIT_ON_CLOSE))
