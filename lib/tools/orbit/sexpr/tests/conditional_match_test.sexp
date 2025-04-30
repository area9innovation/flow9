// Test for conditional pattern matching

// Define test values
(define val1 5)
(define val2 15)
(define val3 25)

(println "Testing conditional pattern matching:")

// Simple conditional match
(println "Test with simple condition:")
(println (match val1
  ((n 0 (> n 10)) "greater than 10")
  (n "less than or equal to 10")))

(println (match val2
  ((n 0 (> n 10)) "greater than 10")
  (n "less than or equal to 10")))

// Multiple conditional patterns
(println "\nTest with multiple conditions:")
(println (match val3
  ((n 0 (> n 20)) "greater than 20")
  ((n 0 (> n 10)) "between 11 and 20")
  (n "less than or equal to 10")))

// Test with list pattern and condition
(define point1 (list 5 10))
(define point2 (list -3 7))

(println "\nTest with list patterns and conditions:")
(println (match point1
  ((p 0 (> (car p) 0)) "positive x")
  (p "non-positive x")))

(println (match point2
  ((p 0 (> (car p) 0)) "positive x")
  (p "non-positive x")))