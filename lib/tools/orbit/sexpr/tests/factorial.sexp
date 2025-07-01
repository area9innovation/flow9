(begin
	(define factorial (lambda (n) (match n 0 1 1 1 n (* n (factorial (- n 1))))))
	(println (+ "Factorial of 5: " (i2s (factorial 5))))
)