// Test calling a lambda defined within the ograph
(define g-internal (makeOGraph "internal-lambda-graph"))

// Create an expression with a lambda definition and call
(define lambda-expr 
  (quote 
    (begin
      (define add (lambda (a b) (+ a b)))
      (add 5 7)
    )))

(define node-id (addSexpr2OGraph g-internal lambda-expr))

(println "Before evaluation:")
(println (extractOGraphSexpr g-internal node-id))

// Save dot visualization before evaluation
(define dot-before (ograph2dot g-internal))
(setFileContent "/home/alstrup/internal-lambda-before.dot" dot-before)

// Evaluate with tracing
(define result (evaluateOGraphQuasiquote g-internal node-id true))

(println "\nAfter evaluation:")
(println (extractOGraphSexpr g-internal result))

// Save dot visualization after evaluation
(define dot-after (ograph2dot g-internal))
(setFileContent "/home/alstrup/internal-lambda-after.dot" dot-after)