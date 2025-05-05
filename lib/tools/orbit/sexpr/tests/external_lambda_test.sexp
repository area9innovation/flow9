// Define an external lambda in the environment
(define multiply (lambda (x y) (* x y)))

// Test calling a lambda from the environment
(define g-external (makeOGraph "external-lambda-graph"))

// Create an expression that calls the external lambda
(define lambda-expr (quote (multiply 6 8)))

(define node-id (addSexpr2OGraph g-external lambda-expr))

(println "Before evaluation:")
(println (extractOGraphSexpr g-external node-id))

// Save dot visualization before evaluation
(define dot-before (ograph2dot g-external))
(setFileContent "/home/alstrup/external-lambda-before.dot" dot-before)

// Evaluate with tracing
(define result (evaluateOGraphQuasiquote g-external node-id true))

(println "\nAfter evaluation:")
(println (extractOGraphSexpr g-external result))

// Save dot visualization after evaluation
(define dot-after (ograph2dot g-external))
(setFileContent "/home/alstrup/external-lambda-after.dot" dot-after)