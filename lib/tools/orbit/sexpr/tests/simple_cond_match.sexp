// simple_cond_match.sexp

// Define a simple "greater than 10" condition
(define test-gt
  (lambda (n)
    (begin
      (println "Testing if " n " > 10: ")
      (match n
        ;; Conditional pattern with condition and result
        (x (> x 10) "Greater than 10")
        ;; Simple variable pattern
        (x "Not greater than 10")
      )
    )
  )
)

// Run tests
(println (test-gt 15))
(println (test-gt 5))