// Test for complex operator evaluation in OGraph quasiquote

// Define some variables in our environment
(define x 10)
(define y 20)

(println "Environment initialized with x=" x ", y=" y)

// ===== Test operator in list =====
(println "\n==== Testing operator in list ====")

// Create dedicated OGraph for this test
(define g-list-op (makeOGraph "list-with-operator-graph"))

// Add list with operators
(define list-op-expr (quote (list (+ 1 2) (* 3 4) (- 10 5) (/ 20 4))))
(define list-op-id (addSexpr2OGraph g-list-op list-op-expr))

(println "Before evaluation:")
(println (extractOGraphSexpr g-list-op list-op-id))

// Save dot visualization before evaluation
(define list-op-dot-before (ograph2dot g-list-op))
(setFileContent "/home/alstrup/list-operators-before.dot" list-op-dot-before)
(println "Graph before evaluation saved")

// Evaluate with tracing
(define list-op-result (evaluateOGraphQuasiquote g-list-op list-op-id true))

(println "\nAfter evaluation:")
(println (extractOGraphSexpr g-list-op list-op-result))
(println "Type: " (astname (extractOGraphSexpr g-list-op list-op-result)))

// Save dot visualization after evaluation
(define list-op-dot-after (ograph2dot g-list-op))
(setFileContent "/home/alstrup/list-operators-after.dot" list-op-dot-after)
(println "Graph after evaluation saved")

// ===== Test complex nested expressions =====
(println "\n==== Testing complex nested expressions ====")

// Create dedicated OGraph for nested complex expressions
(define g-complex (makeOGraph "complex-expr-graph"))

// Add complex expression with variables and nested operations
(define complex-expr (quote (+ (* x 2) (/ (- y 5) 3))))
(define complex-id (addSexpr2OGraph g-complex complex-expr))

(println "Before evaluation:")
(println (extractOGraphSexpr g-complex complex-id))

// Save dot visualization before evaluation
(define complex-dot-before (ograph2dot g-complex))
(setFileContent "/home/alstrup/complex-before.dot" complex-dot-before)
(println "Graph before evaluation saved")

// Evaluate with tracing
(define complex-result (evaluateOGraphQuasiquote g-complex complex-id true))

(println "\nAfter evaluation:")
(println (extractOGraphSexpr g-complex complex-result))
(println "Type: " (astname (extractOGraphSexpr g-complex complex-result)))

// Save dot visualization after evaluation
(define complex-dot-after (ograph2dot g-complex))
(setFileContent "/home/alstrup/complex-after.dot" complex-dot-after)
(println "Graph after evaluation saved")

(println "\nComplex operator evaluation tests completed.")