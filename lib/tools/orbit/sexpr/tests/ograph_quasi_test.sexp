// Test of OGraph Quasiquotation

// First create a new OGraph
(define g (makeOGraph "test-graph"))

// Add some expressions to the graph
(define n1 (addSexpr2OGraph g 1))
(define n2 (addSexpr2OGraph g 2))
(define n3 (addSexpr2OGraph g 3))

// Build a more complex expression: (+ 1 2)
(define add-expr (addSexpr2OGraph g (quote + 1 2)))

;; Build a quasiquoted expression: `(list 1 ,(+ 2 3) 4)
(define quasi-expr (addSexpr2OGraph g
  (quote (quasiquote (list 1 (unquote (+ 2 3)) 4)))))

;; Extract and print the initial expressions
(println "Original add expression:")
(println (extractOGraphSexpr g add-expr))

(println "Original quasi expression:")
(println (extractOGraphSexpr g quasi-expr))

;; Evaluate the add expression using evaluateOGraphQuasiquote
(define eval-add (evaluateOGraphQuasiquote g add-expr))
(println "\nAfter evaluating add expression:")
(println (extractOGraphSexpr g eval-add))

;; Evaluate the quasiquoted expression
(define eval-quasi (evaluateOGraphQuasiquote g quasi-expr))
(println "\nAfter evaluating quasi expression:")
(println (extractOGraphSexpr g eval-quasi))

;; Now create a more complex nested expression
(define complex-expr (addSexpr2OGraph g
  (quote (quasiquote (list (+ 1 2) (unquote (* 3 4)) (quasiquote (+ (unquote (- 5 1)) 6)))))))

(println "\nOriginal complex expression:")
(println (extractOGraphSexpr g complex-expr))

;; Evaluate the complex expression
(define eval-complex (evaluateOGraphQuasiquote g complex-expr))
(println "\nAfter evaluating complex expression:")
(println (extractOGraphSexpr g eval-complex))

;; Test unquote-splicing
(define splice-expr (addSexpr2OGraph g
  (quote (quasiquote (list 1 (unquote-splicing (list 2 3 4)) 5)))))

(println "\nOriginal splice expression:")
(println (extractOGraphSexpr g splice-expr))

;; Evaluate with splicing
(define eval-splice (evaluateOGraphQuasiquote g splice-expr))
(println "\nAfter evaluating splice expression:")
(println (extractOGraphSexpr g eval-splice))
