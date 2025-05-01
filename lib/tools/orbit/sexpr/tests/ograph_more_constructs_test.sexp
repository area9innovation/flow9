// More tests for OGraph quasiquote constructs
// Each test uses a separate OGraph to keep the DOT files clean

// Define common environment values for all tests
(define x 10)
(define y 20)
(define z 30)
(define lst (list 1 2 3))

(println "Environment initialized")

// ===== 1. Test if-expression - false branch =====
(println "\n==== Testing if-false ====")

// Create dedicated OGraph for this test
(define g-if-false (makeOGraph "if-false-graph"))
(define if-false-expr (quote (if false (+ x y) (* x y))))
(define if-false-id (addSexpr2OGraph g-if-false if-false-expr))

(println "Before evaluation:")
(println (extractOGraphSexpr g-if-false if-false-id))

// Save dot visualization before evaluation
(define if-false-dot-before (ograph2dot g-if-false))
(setFileContent "/home/alstrup/if-false-before.dot" if-false-dot-before)
(println "Graph before evaluation saved")

// Evaluate with tracing
(define if-false-result (evaluateOGraphQuasiquote g-if-false if-false-id true))

(println "\nAfter evaluation:")
(println (extractOGraphSexpr g-if-false if-false-result))
(println "Type: " (astname (extractOGraphSexpr g-if-false if-false-result)))

// Save dot visualization after evaluation
(define if-false-dot-after (ograph2dot g-if-false))
(setFileContent "/home/alstrup/if-false-after.dot" if-false-dot-after)
(println "Graph after evaluation saved")

// ===== 2. Test and-expression - all true =====
(println "\n==== Testing and-true ====")

// Create dedicated OGraph for this test
(define g-and-true (makeOGraph "and-true-graph"))
(define and-true-expr (quote (and true (> x 5) (< y 30))))
(define and-true-id (addSexpr2OGraph g-and-true and-true-expr))

(println "Before evaluation:")
(println (extractOGraphSexpr g-and-true and-true-id))

// Save dot visualization before evaluation
(define and-true-dot-before (ograph2dot g-and-true))
(setFileContent "/home/alstrup/and-true-before.dot" and-true-dot-before)
(println "Graph before evaluation saved")

// Evaluate with tracing
(define and-true-result (evaluateOGraphQuasiquote g-and-true and-true-id true))

(println "\nAfter evaluation:")
(println (extractOGraphSexpr g-and-true and-true-result))
(println "Type: " (astname (extractOGraphSexpr g-and-true and-true-result)))

// Save dot visualization after evaluation
(define and-true-dot-after (ograph2dot g-and-true))
(setFileContent "/home/alstrup/and-true-after.dot" and-true-dot-after)
(println "Graph after evaluation saved")

// ===== 3. Test and-expression - short-circuit false =====
(println "\n==== Testing and-false ====")

// Create dedicated OGraph for this test
(define g-and-false (makeOGraph "and-false-graph"))
(define and-false-expr (quote (and (> x 5) false (< y 30))))
(define and-false-id (addSexpr2OGraph g-and-false and-false-expr))

(println "Before evaluation:")
(println (extractOGraphSexpr g-and-false and-false-id))

// Save dot visualization before evaluation
(define and-false-dot-before (ograph2dot g-and-false))
(setFileContent "/home/alstrup/and-false-before.dot" and-false-dot-before)
(println "Graph before evaluation saved")

// Evaluate with tracing
(define and-false-result (evaluateOGraphQuasiquote g-and-false and-false-id true))

(println "\nAfter evaluation:")
(println (extractOGraphSexpr g-and-false and-false-result))
(println "Type: " (astname (extractOGraphSexpr g-and-false and-false-result)))

// Save dot visualization after evaluation
(define and-false-dot-after (ograph2dot g-and-false))
(setFileContent "/home/alstrup/and-false-after.dot" and-false-dot-after)
(println "Graph after evaluation saved")

// ===== 4. Test or-expression with short-circuit ===== 
(println "\n==== Testing or-true ====")

// Create dedicated OGraph for this test
(define g-or-true (makeOGraph "or-true-graph"))
(define or-true-expr (quote (or (< x 5) (> y 15) (= z 100))))
(define or-true-id (addSexpr2OGraph g-or-true or-true-expr))

(println "Before evaluation:")
(println (extractOGraphSexpr g-or-true or-true-id))

// Save dot visualization before evaluation
(define or-true-dot-before (ograph2dot g-or-true))
(setFileContent "/home/alstrup/or-true-before.dot" or-true-dot-before)
(println "Graph before evaluation saved")

// Evaluate with tracing
(define or-true-result (evaluateOGraphQuasiquote g-or-true or-true-id true))

(println "\nAfter evaluation:")
(println (extractOGraphSexpr g-or-true or-true-result))
(println "Type: " (astname (extractOGraphSexpr g-or-true or-true-result)))

// Save dot visualization after evaluation
(define or-true-dot-after (ograph2dot g-or-true))
(setFileContent "/home/alstrup/or-true-after.dot" or-true-dot-after)
(println "Graph after evaluation saved")

// ===== 5. Test begin with multiple expressions =====
(println "\n==== Testing begin ====")

// Create dedicated OGraph for this test
(define g-begin (makeOGraph "begin-graph"))
(define begin-expr (quote (begin (+ 1 2) (- y 5) (* x z))))
(define begin-id (addSexpr2OGraph g-begin begin-expr))

(println "Before evaluation:")
(println (extractOGraphSexpr g-begin begin-id))

// Save dot visualization before evaluation
(define begin-dot-before (ograph2dot g-begin))
(setFileContent "/home/alstrup/begin-before.dot" begin-dot-before)
(println "Graph before evaluation saved")

// Evaluate with tracing
(define begin-result (evaluateOGraphQuasiquote g-begin begin-id true))

(println "\nAfter evaluation:")
(println (extractOGraphSexpr g-begin begin-result))
(println "Type: " (astname (extractOGraphSexpr g-begin begin-result)))

// Save dot visualization after evaluation
(define begin-dot-after (ograph2dot g-begin))
(setFileContent "/home/alstrup/begin-after.dot" begin-dot-after)
(println "Graph after evaluation saved")

(println "\nAll additional construct tests completed.")