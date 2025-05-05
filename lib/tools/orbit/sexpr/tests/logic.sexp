;; logic.sexp - S-expression version of logic rewriting test
;; Demonstrates CNF and DNF transformations using orbit libraries

(begin
  ;; Import the orbit libraries
  (import "lib/rewrite.orb")
  (import "lib/logic.orb")
  
  ;; Main test function
  (define (main)
    (println "==== CNF and DNF Canonical Forms with Gather/Scatter ====")
    
    ;; Test expressions
    (define test-expressions
      (list
        (quote (! (a && b)))             ;; De Morgan's law test
        (quote (a || (b && c)))          ;; OR over AND distribution (CNF)
        (quote (a && (b || c)))          ;; AND over OR distribution (DNF)
        (quote ((a || b) && (!a || c)))  ;; A practical example - resolution candidate
        (quote (a || b || c || (d && e && f)))  ;; Multiple nested operators
        (quote (a+b < 2 || c > 3 || c > 3))
      ))
    
    ;; Process each test case
    (define count 1)
    (fold test-expressions count
          (lambda (i expr)
            (println (+ "\n----- Test Case " (i2s i) " -----"))
            (println (+ "Original: " (prettyOrbit expr)))
            (println (+ "CNF: " (prettyOrbit (to_cnf expr))))
            (println (+ "DNF: " (prettyOrbit (to_dnf expr))))
            (+ i 1)))
    
    "Done")
  
  ;; Run the demonstration
  (main)
)