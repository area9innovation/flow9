(begin
  ;; Define a vector
  (define v [1 2 3])
  
  ;; Print the vector
  (println "Vector:" v)
  
  ;; Use vector in calculation
  (define sum-fn (lambda (vec)
    (fold vec 0 +)))
  
  (println "Sum of vector elements:" (sum-fn v))
  
  ;; Pattern matching with vectors
  (define match-vec (lambda (v)
    (match v
      [1 2 3] "Vector [1 2 3]"
      [1 2 _] "Vector [1 2 x]"
      _ "Unknown vector")))
  
  (println "Pattern match 1:" (match-vec [1 2 3]))
  (println "Pattern match 2:" (match-vec [1 2 4]))
  
  ;; Quasiquotation with vectors
  (define x 42)
  (define qv (quasiquote [1 2 (unquote x)]))
  (println "Quasiquoted vector:" qv)
)