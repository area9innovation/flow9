(begin
  ;; Create an OGraph
  (define graph-name (makeOGraph "domain-test"))
  
  ;; Add two domains for testing
  (define number-domain-id (addOGraph graph-name NumberDomain))
  (define string-domain-id (addOGraph graph-name StringDomain))
  
  ;; Add a number with NumberDomain
  (define num-expr-id (addOGraph graph-name 42))
  (addDomainToNode graph-name num-expr-id number-domain-id)
  
  ;; Add a string with StringDomain
  (define str-expr-id (addOGraph graph-name "hello"))
  (addDomainToNode graph-name str-expr-id string-domain-id)
  
  ;; Add another number with no domain
  (define untyped-num-id (addOGraph graph-name 123))
  
  ;; Print all expressions
  (println "Added expressions:")
  (println (+ "Number with NumberDomain: " (prettySexpr (extractOGraph graph-name num-expr-id))))
  (println (+ "String with StringDomain: " (prettySexpr (extractOGraph graph-name str-expr-id))))
  (println (+ "Untyped number: " (prettySexpr (extractOGraph graph-name untyped-num-id))))
  
  ;; Define a callback for pattern matching
  (define print-match
    (lambda (bindings eclass-id)
      (begin
        (println "Match found!")
        (println (+ "E-class ID: " (i2s eclass-id)))
        (println (+ "Bindings: " (prettySexpr bindings)))
        (println (+ "Expression: " (prettySexpr (extractOGraph graph-name eclass-id)))))))
  
  ;; 1. POSITIVE DOMAIN MATCHING
  (println "\n1. POSITIVE DOMAIN MATCHING (: x NumberDomain) - should match only the number with NumberDomain")
  (define matches1 
    (matchOGraphPattern graph-name 
      (quasiquote (: x NumberDomain)) 
      print-match))
      
  (println (+ "Number of matches: " (i2s matches1)))
  
  ;; 2. NEGATIVE DOMAIN MATCHING
  (println "\n2. NEGATIVE DOMAIN MATCHING (!: x NumberDomain) - should match string and untyped number")
  (define matches2 
    (matchOGraphPattern graph-name 
      (quasiquote (!: x NumberDomain)) 
      print-match))
      
  (println (+ "Number of matches: " (i2s matches2)))
  
  ;; 3. MATCH ANY INTEGER WITH NO DOMAIN
  (println "\n3. MATCHING INTEGERS WITH NO DOMAIN (!: x d) - should match untyped number")
  (define matches3
    (matchOGraphPattern graph-name 
      (quasiquote (!: x d)) 
      (lambda (bindings eclass-id)
        (begin
          (println "Match found with domain negation!")
          (println (+ "E-class ID: " (i2s eclass-id)))
          (println (+ "Bindings: " (prettySexpr bindings)))
          (println (+ "Expression: " (prettySexpr (extractOGraph graph-name eclass-id))))))))
  
  (println (+ "Number of matches: " (i2s matches3)))
)
