// First create a new OGraph
(define g (makeOGraph "lambda-test-graph"))

// Define some variables in our environment
(define x 10)
(define y 20)
(define z 30)

// Create a lambda expression that captures x and y but not z
// (lambda (a) (+ a (+ x y)))
(define lambda-expr (addSexpr2OGraph g (quote (lambda (a) (+ a (+ x y))))))

(println "\nOriginal lambda expression:")
(println (extractOGraphSexpr g lambda-expr))

// Evaluate the lambda expression using evaluateOGraphQuasiquote with tracing enabled
// This should result in a closure with captured environment
(define eval-lambda (evaluateOGraphQuasiquote g lambda-expr true))

(println "\nAfter evaluating lambda expression:")
(println (extractOGraphSexpr g eval-lambda))

// Get the type of result to see if it was converted to a closure properly
(println "Type of evaluation result: " (astname (extractOGraphSexpr g eval-lambda)))

// Visualize the OGraph structures
(println (setFileContent
  "/home/alstrup/area9/flow9/lib/tools/orbit/sexpr/lambda-test-graph.dot"
	(ograph2dot "lambda-test-graph")
))
(println "OGraph structure saved to /home/alstrup/area9/flow9/lib/tools/orbit/sexpr/lambda-test-graph.dot")
