// Final test for conditional pattern matching

(println "Conditional pattern matching test:")

// Define test function for numbers
(define classify-num
  (lambda (n)
    (match n
      // Format (pattern condition result)
      (x (> x 20) "greater than 20")
      (x (> x 10) "between 11 and 20")
      (x (< x 5) "less than 5")
      (x "between 5 and 10"))))

// Test with different values
(println "5: " (classify-num 5))
(println "3: " (classify-num 3))
(println "15: " (classify-num 15))
(println "25: " (classify-num 25))

// Define test function for coordinates
(define classify-point
  (lambda (pt)
    (match pt
      // With conditions
      (p (> (car p) 0) "positive x")
      (p (> (car (cdr p)) 0) "non-positive x, positive y")
      // Without condition - default case
      (p "no positive coordinates"))))

// Test with different points
(println "\nCoordinate tests:")
(println "[5, 10]: " (classify-point (list 5 10)))
(println "[-3, 7]: " (classify-point (list -3 7)))
(println "[-2, -3]: " (classify-point (list -2 -3)))

// Test with nested patterns
(define complex-match
  (lambda (val)
    (match val
      // Match strings with specific condition
      (s (and (isString s) (= (strlen s) 5)) "5-letter string")
      // Match lists with specific length
      (lst (and (isArray lst) (= (length lst) 2)) "2-element list")
      // Match numbers in specific range  
      (n (and (isInt n) (> n 0) (< n 100)) "positive number < 100")
      // Default
      (x (+ "other: " (astname x))))))

(println "\nComplex pattern tests:")
(println "'hello': " (complex-match "hello"))
(println "'hi': " (complex-match "hi"))
(println "[1, 2]: " (complex-match (list 1 2)))
(println "[1, 2, 3]: " (complex-match (list 1 2 3)))
(println "42: " (complex-match 42))
(println "200: " (complex-match 200))
(println "true: " (complex-match true))