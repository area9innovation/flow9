// Test array functions
(
	begin
	(import "lib/array")
	(define numbers (list 1 2 3 4 5))
	(define doubled (map numbers (lambda (x) (* x 2))))
	(println doubled)
)