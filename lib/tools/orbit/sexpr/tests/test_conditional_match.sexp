// test_conditional_match.sexp

// Helper function (define outside lambda for clarity if needed)
(define isEven (lambda (n) (= (mod n 2) 0)))
(define isOdd (lambda (n) (not (isEven n))))

(define check-value
  (lambda (val)
    (match val
      // 1. Conditional pattern: Match integer 'x' IF (> x 10)
      (x (begin (println "Testing condition (and (isInt x) (> x 10)) with x =" (prettySexpr x)) (and (isInt x) (> x 10))) (quasiquote (large (unquote x))))

      // 2. Conditional pattern: Match integer 'x' IF (isEven x)
      (x (and (isInt x) (isEven x)) (quasiquote (even (unquote x))))

      // 6. Conditional pattern: Match only if actually an integer
      (x (isInt x) (quasiquote (int (unquote x))))

      // 4. Conditional pattern: Match list '(a b)' IF (> a b)
      ((a b) (begin (println "Testing list condition with a =" (prettySexpr a) ", b =" (prettySexpr b)) (and (isInt a) (isInt b) (> a b))) (quasiquote (ordered-pair (unquote a) (unquote b))))

       // 5. Non-conditional pattern: Match list '(a b)'
      ((a b) (quasiquote (pair (unquote a) (unquote b))))

      // Default case
      (other (quasiquote (other-type (unquote other))))
    )))

(println "Testing 15:")
(println (prettySexpr (check-value 15))) // Expected: (large 15) - Matches #1

(println "Testing 8:")
(println (prettySexpr (check-value 8)))  // Expected: (even 8) - Skips #1, Matches #2

(println "Testing 7:")
(println (prettySexpr (check-value 7)))  // Expected: (int 7) - Skips #1, #2, Matches #3

(println "Testing (list 5 2):")
(println (prettySexpr (check-value (list 5 2)))) // Expected: (ordered-pair 5 2) - Matches #4

(println "Testing (list 2 5):")
(println (prettySexpr (check-value (list 2 5)))) // Expected: (pair 2 5) - Skips #4, Matches #5

(println "Testing \"hello\":")
(println (prettySexpr (check-value "hello"))) // Expected: (other-type "hello") - Matches default

