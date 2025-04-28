(
	begin
	// Define variables for quasiquote examples
	(define x 10)
	(define lst (quote (2 3)))
	(
		println

		// Quoting examples
		(quote (1 2 3))

		// QuasiQuoting with unquote and unquote-splicing
		(quasiquote (1 (unquote x) 3))
		(quasiquote (1 (unquote-splicing lst) 4))
	)
)