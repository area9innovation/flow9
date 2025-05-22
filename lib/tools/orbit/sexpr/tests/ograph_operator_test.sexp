// Test for operator evaluation in OGraph quasiquote

// Define some variables in our environment
(define x 10)
(define y 20)

(println "Environment initialized with x=" x ", y=" y)

// ===== Test direct operator expression =====
(println "\n==== Testing operator expression ====")

// Create dedicated OGraph for this test
(define g-op (makeOGraph "operator-graph"))

// Add simple arithmetic expression
(define op-expr (quote (+ 1 2)))
(define op-id (addSexpr2OGraph g-op op-expr))

(println "Before evaluation:")
(println (extractOGraphSexpr g-op op-id))

// Save dot visualization before evaluation
(define op-dot-before (ograph2dot g-op))
(setFileContent "/home/alstrup/operator-before.dot" op-dot-before)
(println "Graph before evaluation saved")

// Evaluate with tracing
(define op-result (evaluateOGraphQuasiquote g-op op-id true))

(println "\nAfter evaluation:")
(println (extractOGraphSexpr g-op op-result))
(println "Type: " (astname (extractOGraphSexpr g-op op-result)))

// Save dot visualization after evaluation
(define op-dot-after (ograph2dot g-op))
(setFileContent "/home/alstrup/operator-after.dot" op-dot-after)
(println "Graph after evaluation saved")

// ===== Test nested operator expressions =====
(println "\n==== Testing nested operator expressions ====")

// Create dedicated OGraph for nested expressions
(define g-nested (makeOGraph "nested-operator-graph"))

// Add nested arithmetic expression
(define nested-expr (quote (+ 1 (* 2 3))))
(define nested-id (addSexpr2OGraph g-nested nested-expr))

(println "Before evaluation:")
(println (extractOGraphSexpr g-nested nested-id))

// Save dot visualization before evaluation
(define nested-dot-before (ograph2dot g-nested))
(setFileContent "/home/alstrup/nested-before.dot" nested-dot-before)
(println "Graph before evaluation saved")

// Evaluate with tracing
(define nested-result (evaluateOGraphQuasiquote g-nested nested-id true))

(println "\nAfter evaluation:")
(println (extractOGraphSexpr g-nested nested-result))
(println "Type: " (astname (extractOGraphSexpr g-nested nested-result)))

// Save dot visualization after evaluation
(define nested-dot-after (ograph2dot g-nested))
(setFileContent "/home/alstrup/nested-after.dot" nested-dot-after)
(println "Graph after evaluation saved")

(println "\nOperator evaluation tests completed.")