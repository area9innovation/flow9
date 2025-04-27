;; Quoting examples
'(1 2 3)

;; Define variables for quasiquote examples
(define x 10)
(define lst '(2 3))

;; QuasiQuoting with unquote and unquote-splicing
`(1 $x 3)
`(1 $lst 4)
`(1 #lst 4)