// test_rest_pattern.sexp

// Define a sample list
(define mylist (quote (+ 10 20 30 40)))
(define mylist2 (quote (+ 10))) // Edge case: only one fixed element, empty rest
(define mylist3 (quote (1 2 3)))   // Different head
(define notalist 5)

// Define a transformation function using match with rest pattern
(define transform
  (lambda (expr)
    (match expr
      // Pattern: (+ fixed ... restArgs)  <-- Use variable '...'
      ((+ fixed ... restArgs)
       // Result: Reconstruct as (* fixed restArgs...)
       (quasiquote (* (unquote fixed) (unquote-splicing restArgs))))

      // Pattern: (a ... rest) <-- Use variable '...'
       ((a ... rest)
        (quasiquote (list (unquote a) " matched with rest: " (unquote rest))))

      // Default case
      (other
       (quasiquote (unmatched (unquote other))))
    )))

// Run tests
(println "Testing (+ 10 20 30 40):")
(println (prettySexpr (transform mylist))) // Expected: (* 10 20 30 40)

(println "Testing (+ 10):")
(println (prettySexpr (transform mylist2))) // Expected: (* 10)

(println "Testing (1 2 3):")
(println (prettySexpr (transform mylist3))) // Expected: (list 1 " matched with rest: " (2 3))

(println "Testing 5:")
(println (prettySexpr (transform notalist))) // Expected: (unmatched 5)

(println "Test with only rest:")
(define transform2
  (lambda (expr)
    (match expr
      ((... all) // <-- Use variable '...'
       (quasiquote (all-elements (unquote-splicing all))))
      (other (quasiquote (unmatched (unquote other))))
    )))
(println (prettySexpr (transform2 (quote (a b c))))) // Expected: (all-elements a b c)
(println (prettySexpr (transform2 (quote ()))))     // Expected: (all-elements)

