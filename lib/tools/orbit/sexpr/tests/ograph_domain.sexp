(begin
  ;; Create an OGraph
  (define graph-name (makeOGraph "domain-test"))
  
  ;; Add the NumberDomain constructor first, which will act as our domain
  (define domain-id 
    (addOGraph graph-name NumberDomain))
  
  ;; Add an expression with a domain annotation
  (define expr-id 
    (addOGraph graph-name 42))
    
  ;; Add the domain to the expression
  (addDomainToNode graph-name expr-id domain-id)
  
  ;; Print the added expression and its domain(s)
  (println "Added expression:")
  (println (prettySexpr (extractOGraph graph-name expr-id)))
  
  ;; Define a callback for pattern matching
  (define print-match
    (lambda (bindings eclass-id)
      (begin
        (println "Match found!")
        (println (+ "E-class ID: " (i2s eclass-id)))
        (println (+ "Bindings: " (prettySexpr bindings)))
        (println (+ "Expression: " (prettySexpr (extractOGraph graph-name eclass-id)))))))
  
  ;; Match the domain pattern
  (println "\nMatching pattern (: x NumberDomain)...")
  (matchOGraphPattern graph-name 
	(quasiquote (: x NumberDomain)) 
	print-match)
)
