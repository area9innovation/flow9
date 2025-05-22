
(begin
  (println "==== Special Form OGraph Representation Test ====")

  ;; Define a variable used in the test expression
  (define x 10)

  ;; Create a new OGraph
  (define g-test (makeOGraph "special-form-test-graph"))
  (println (+ "Created OGraph: " g-test))

  ;; Define the S-expression with a special form (if)
  (define if-expr (quote (if (> x 5) (+ x 1) (- x 1))))
  (println (+ "Original S-expression: " (prettySexpr if-expr)))

  ;; Add the S-expression to the OGraph
  (define node-id (addSexpr2OGraph g-test if-expr))
  (println (+ "Added expression to graph, node ID: " (i2s node-id)))

  ;; Extract the S-expression back from the OGraph
  (define extracted-expr (extractOGraphSexpr g-test node-id))
  (println (+ "Extracted S-expression: " (prettySexpr extracted-expr)))

  ;; Check if the extracted expression matches the original structure
  ;; We expect (if (> x 5) (+ x 1) (- x 1))
  (println (+ "Extraction matches original? " (b2s (= if-expr extracted-expr))))

  ;; (Optional) Save DOT graph for visual inspection
  (define dot-graph (ograph2dot g-test))
  (setFileContent "/home/alstrup/special_form_test.dot" dot-graph)
  (println "Graph saved to /home/alstrup/special_form_test.dot")
  (println "-> Inspect this file to verify the 'if' SpecialForm node has the name in its value field.")

  ;; Test evaluateOGraphQuasiquote which uses the modified isSpecialFormNode
  (println "
Testing evaluateOGraphQuasiquote...")
  (define eval-result (evaluateOGraphQuasiquote g-test node-id true)) ;; Enable tracing
  (println (+ "Quasiquote evaluation result node ID: " (i2s eval-result)))
  (define final-expr (extractOGraphSexpr g-test eval-result))
  (println (+ "Expression after quasiquote evaluation: " (prettySexpr final-expr)))
  ;; Expected result: Since x=10, (> x 5) is true, it should evaluate to (+ x 1) -> (+ 10 1) -> 11
  (println (+ "Final evaluated expression matches expected (11)? " (b2s (= final-expr (quote 11)))))

  (println "==== Test Complete ====")
)
