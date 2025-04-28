// Closure tests
(
	(define y 20)  // Define a variable to capture
	(define z 30)  // Another variable to capture
	(define add-y (lambda (x) (+ x y)))  // Create a closure capturing y
	(add-y 5)  // Should return 25
	(define y 100)  // Change y after closure creation
	(add-y 5)  // Should still return 25 because closure captured original y

	// Nested closure test
	(define make-adder (lambda (n) (lambda (x) (+ x n))))
	(define add10 (make-adder 10))
	(define add20 (make-adder 20))
	(add10 5)  // Should return 15
	(add20 5)  // Should return 25

	// Multiple variable capture
	(define calculate (lambda (x) (+ x y z)))  // Captures both y and z
	(calculate 5)  // Should use the captured y (100) and z (30)
)
