// Comprehensive test for all OGraph quasiquote constructs
// Each test uses a separate OGraph to keep the DOT files clean

// Define common environment values for all tests
(define x 10)
(define y 20)
(define z 30)
(define flag true)

(println "Environment initialized with x=" x ", y=" y ", z=" z ", flag=" flag)

// ===== 1. Test constant evaluation =====
(println "\n==== Testing constants ====")

// Create dedicated OGraph for this test
(define g-const (makeOGraph "constants-graph"))
(define const-expr (quote (list 1 2.5 "string" true)))
(define const-id (addSexpr2OGraph g-const const-expr))

(println "Before evaluation:")
(println (extractOGraphSexpr g-const const-id))

// Save dot visualization before evaluation
(define const-dot-before (ograph2dot g-const))
(setFileContent "/home/alstrup/constants-before.dot" const-dot-before)
(println "Graph before evaluation saved to /home/alstrup/constants-before.dot")

// Evaluate with tracing
(define const-result (evaluateOGraphQuasiquote g-const const-id true))

(println "\nAfter evaluation:")
(println (extractOGraphSexpr g-const const-result))
(println "Type: " (astname (extractOGraphSexpr g-const const-result)))

// Save dot visualization after evaluation
(define const-dot-after (ograph2dot g-const))
(setFileContent "/home/alstrup/constants-after.dot" const-dot-after)
(println "Graph after evaluation saved to /home/alstrup/constants-after.dot")

// ===== 2. Test variable evaluation =====
(println "\n==== Testing variables ====")

// Create dedicated OGraph for this test
(define g-var (makeOGraph "variables-graph"))
(define var-expr (quote (list x y z)))
(define var-id (addSexpr2OGraph g-var var-expr))

(println "Before evaluation:")
(println (extractOGraphSexpr g-var var-id))

// Save dot visualization before evaluation
(define var-dot-before (ograph2dot g-var))
(setFileContent "/home/alstrup/variables-before.dot" var-dot-before)
(println "Graph before evaluation saved to /home/alstrup/variables-before.dot")

// Evaluate with tracing
(define var-result (evaluateOGraphQuasiquote g-var var-id true))

(println "\nAfter evaluation:")
(println (extractOGraphSexpr g-var var-result))
(println "Type: " (astname (extractOGraphSexpr g-var var-result)))

// Save dot visualization after evaluation
(define var-dot-after (ograph2dot g-var))
(setFileContent "/home/alstrup/variables-after.dot" var-dot-after)
(println "Graph after evaluation saved to /home/alstrup/variables-after.dot")

// ===== 3. Test operator evaluation with constants =====
(println "\n==== Testing operators ====")

// Create dedicated OGraph for this test
(define g-op (makeOGraph "operators-graph"))
(define op-expr (quote (list (+ 1 2) (* 3 4) (- 10 5) (/ 20 4))))
(define op-id (addSexpr2OGraph g-op op-expr))

(println "Before evaluation:")
(println (extractOGraphSexpr g-op op-id))

// Save dot visualization before evaluation
(define op-dot-before (ograph2dot g-op))
(setFileContent "/home/alstrup/operators-before.dot" op-dot-before)
(println "Graph before evaluation saved to /home/alstrup/operators-before.dot")

// Evaluate with tracing
(define op-result (evaluateOGraphQuasiquote g-op op-id true))

(println "\nAfter evaluation:")
(println (extractOGraphSexpr g-op op-result))
(println "Type: " (astname (extractOGraphSexpr g-op op-result)))

// Save dot visualization after evaluation
(define op-dot-after (ograph2dot g-op))
(setFileContent "/home/alstrup/operators-after.dot" op-dot-after)
(println "Graph after evaluation saved to /home/alstrup/operators-after.dot")

// ===== 4. Test unquote =====
(println "\n==== Testing unquote ====")

// Create dedicated OGraph for this test
(define g-unq (makeOGraph "unquote-graph"))
(define unq-expr (quote (quasiquote (list (unquote (+ x y)) (unquote (* 2 z))))))
(define unq-id (addSexpr2OGraph g-unq unq-expr))

(println "Before evaluation:")
(println (extractOGraphSexpr g-unq unq-id))

// Save dot visualization before evaluation
(define unq-dot-before (ograph2dot g-unq))
(setFileContent "/home/alstrup/unquote-before.dot" unq-dot-before)
(println "Graph before evaluation saved to /home/alstrup/unquote-before.dot")

// Evaluate with tracing
(define unq-result (evaluateOGraphQuasiquote g-unq unq-id true))

(println "\nAfter evaluation:")
(println (extractOGraphSexpr g-unq unq-result))
(println "Type: " (astname (extractOGraphSexpr g-unq unq-result)))

// Save dot visualization after evaluation
(define unq-dot-after (ograph2dot g-unq))
(setFileContent "/home/alstrup/unquote-after.dot" unq-dot-after)
(println "Graph after evaluation saved to /home/alstrup/unquote-after.dot")

// ===== 5. Test if-expression - true branch =====
(println "\n==== Testing if-true ====")

// Create dedicated OGraph for this test
(define g-if-true (makeOGraph "if-true-graph"))
(define if-true-expr (quote (if true (+ x y) (* x y))))
(define if-true-id (addSexpr2OGraph g-if-true if-true-expr))

(println "Before evaluation:")
(println (extractOGraphSexpr g-if-true if-true-id))

// Save dot visualization before evaluation
(define if-true-dot-before (ograph2dot g-if-true))
(setFileContent "/home/alstrup/if-true-before.dot" if-true-dot-before)
(println "Graph before evaluation saved to /home/alstrup/if-true-before.dot")

// Evaluate with tracing
(define if-true-result (evaluateOGraphQuasiquote g-if-true if-true-id true))

(println "\nAfter evaluation:")
(println (extractOGraphSexpr g-if-true if-true-result))
(println "Type: " (astname (extractOGraphSexpr g-if-true if-true-result)))

// Save dot visualization after evaluation
(define if-true-dot-after (ograph2dot g-if-true))
(setFileContent "/home/alstrup/if-true-after.dot" if-true-dot-after)
(println "Graph after evaluation saved to /home/alstrup/if-true-after.dot")

// ===== 6. Test lambda with environment capture =====
(println "\n==== Testing lambda ====")

// Create dedicated OGraph for this test
(define g-lambda (makeOGraph "lambda-graph"))
(define lambda-expr (quote (lambda (a b) (+ a (+ b (+ x y))))))
(define lambda-id (addSexpr2OGraph g-lambda lambda-expr))

(println "Before evaluation:")
(println (extractOGraphSexpr g-lambda lambda-id))

// Save dot visualization before evaluation
(define lambda-dot-before (ograph2dot g-lambda))
(setFileContent "/home/alstrup/lambda-before.dot" lambda-dot-before)
(println "Graph before evaluation saved to /home/alstrup/lambda-before.dot")

// Evaluate with tracing
(define lambda-result (evaluateOGraphQuasiquote g-lambda lambda-id true))

(println "\nAfter evaluation:")
(println (extractOGraphSexpr g-lambda lambda-result))
(println "Type: " (astname (extractOGraphSexpr g-lambda lambda-result)))

// Save dot visualization after evaluation
(define lambda-dot-after (ograph2dot g-lambda))
(setFileContent "/home/alstrup/lambda-after.dot" lambda-dot-after)
(println "Graph after evaluation saved to /home/alstrup/lambda-after.dot")

(println "\nAll construct tests completed.")