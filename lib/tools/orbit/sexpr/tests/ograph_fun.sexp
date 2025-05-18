;; test_ograph_evaluation.sexp

;; Define a custom function in the SEXP environment
(define square (lambda (x) (* x x)))

;; Define another function that uses the first one
(define sum-of-squares 
  (lambda (a b) 
    (+ (square a) (square b))))

;; Create a new OGraph
(define graph-name (makeOGraph "test-graph"))

;; Add our defined function to the graph in unevaluated form
(define function-node-id 
  (addSexpr2OGraph graph-name 
    (quasiquote (sum-of-squares 3 4))))

;; Now create an expression using quasiquote with the function inside
(define expr-with-function
  (addSexpr2OGraph graph-name
    (quasiquote (+ 10 (unquote (sum-of-squares 3 4))))))

;; Print initial expression
(println "Original expression in OGraph:")
(println (prettySexpr (extractOGraphSexpr graph-name expr-with-function)))

;; Evaluate the expression using our enhanced evaluateOGraphQuasiquote
(define result-node-id 
  (evaluateOGraphQuasiquote graph-name expr-with-function))

;; Extract and print the result
(println "Evaluated expression in OGraph:")
(println (prettySexpr (extractOGraphSexpr graph-name result-node-id)))

;; Alternative approach: directly extract and evaluate a function from the OGraph
;; First add a function definition to the graph
(define function-def-node-id
  (addSexpr2OGraph graph-name
    (lambda (x y) (+ (* x x) (* y y)))))

;; Extract this function definition back into the SEXP environment
(define extracted-function 
  (extractOGraphSexpr graph-name function-def-node-id))

;; Apply the extracted function
(println "Result of applying extracted function:")
(println (prettySexpr (eval (list extracted-function 3 4))))

;; Test with operators as well
(define op-expr-id
  (addSexpr2OGraph graph-name
    (quasiquote (+ 5 (unquote (* 3 4))))))

(println "Operator expression before evaluation:")
(println (prettySexpr (extractOGraphSexpr graph-name op-expr-id)))

(define op-result-id
  (evaluateOGraphQuasiquote graph-name op-expr-id))

(println "Operator expression after evaluation:")
(println (prettySexpr (extractOGraphSexpr graph-name op-result-id)))

;; Export the OGraph to DOT format
(println "Exporting OGraph to DOT format...")

;; Add a helper function to export OGraph to DOT
(define export-ograph-to-dot
  (lambda (name filename)
    (begin
      ;; Convert to DOT format
      (define dot-content (ograph2dot name))
      ;; Save to file
      (println (+ "Saving DOT file to: " filename))
      (setFileContent filename dot-content)
      (println "OGraph exported successfully"))))

;; Export our test graph
(export-ograph-to-dot graph-name "test-graph.dot")