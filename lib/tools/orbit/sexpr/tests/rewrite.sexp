;; rewrite.sexp - Port of rewrite.orb to S-expression Scheme variant
;; Domain-aware rewriting library for OGraph manipulation
(begin

;; Apply a single rewrite pattern and replacement to a graph,
;; correctly handling domain annotations and conditions
(define (applyRewriteRule graph pattern replacement condition ruleName)
  (let ((matches 
         (matchOGraphSexprPattern graph pattern 
           (lambda (bindings eclassId)
             ;; THE CORRECT SEQUENCE FOR DOMAIN-AWARE REWRITING:
             
             ;; Step 1: Check if the condition is satisfied
             (let ((shouldApplyRule 
                    (if (= condition true)
                        ;; Optimize for the common case of condition=true
                        true
                        ;; Substitute bindings into the condition in the graph
                        (let ((condId (addSexprWithSub graph condition bindings))
                              ;; Extract for evaluation
                              (condExpr (extractOGraphSexpr graph condId))
                              ;; Evaluate the condition
                              (condResult (eval condExpr)))
                          condResult))))
               
               (if shouldApplyRule
                   ;; Step 2: Apply the replacement (only if condition is true)
                   ;; Modern approach using direct eclass ID substitution
                   (let ((newId (addSexprWithSub graph replacement bindings))
                         ;; Step 3: Merge nodes (result first to make it canonical)
                         (success (mergeOGraphNodes graph newId eclassId)))
                     success)
                   ;; Condition not satisfied, rule not applied
                   0))))))
    matches))

;; Apply a list of rewrite rules to an expression
;; Rules are quadruples: [name, pattern, replacement, condition]
(define (applyRules expr rules)
  ;; Create a new graph 
  (let ((graph (makeOGraph "transform"))
        ;; Add the expression
        (exprId (addSexpr2OGraph graph expr)))
    
    ;; Helper function to apply rules recursively 
    (letrec ((applyRulesRecursive 
              (lambda (rules index totalMatches)
                (if (< index (length rules))
                    (let ((rule (index rules index))
                          (ruleName (index (index rules index) 0))
                          (pattern (index (index rules index) 1))
                          (replacement (index (index rules index) 2))
                          (condition (if (>= (length (index rules index)) 4) 
                                         (index (index rules index) 3) 
                                         true)))
                      
                      ;; Apply the rule with condition
                      (let ((matches (applyRewriteRule graph pattern replacement condition ruleName)))
                        
                        ;; Apply the next rule
                        (applyRulesRecursive rules (+ index 1) (+ totalMatches matches))))
                    ;; Return total matches when done
                    totalMatches))))
      
      ;; Apply all rules
      (let ((totalMatches (applyRulesRecursive rules 0 0)))
        ;; Return the final transformed expression
        (extractOGraphSexpr graph exprId)))))

;; Prepares a rule with proper domain handling
;; Returns a quadruple of [name, pattern, replacement, condition]
(define (prepareRule name patternExpr replacementExpr conditionExpr)
  (list name patternExpr replacementExpr conditionExpr))

;; Convenience function for rules without conditions
(define (prepareSimpleRule name patternExpr replacementExpr)
  (prepareRule name patternExpr replacementExpr true))

;; Apply a single rule to an expression
(define (applyRule expr name pattern replacement condition)
  (applyRules expr (list (list name pattern replacement condition))))

;; Apply rules until saturation (fixed point)
(define (applyRulesUntilFixedPoint expr rules maxIterations)
  ;; Create a graph with the initial expression
  (let ((graph (makeOGraph "fixed_point"))
        (exprId (addSexpr2OGraph graph expr)))
    
    ;; Function to apply all rules once and count matches
    (define (applyAllRules id rules)
      (letrec ((applyHelper 
                (lambda (index totalMatches)
                  (if (< index (length rules))
                      (let ((rule (index rules index))
                            (ruleName (index (index rules index) 0))
                            (pattern (index (index rules index) 1))
                            (replacement (index (index rules index) 2))
                            (condition (if (>= (length (index rules index)) 4) 
                                           (index (index rules index) 3) 
                                           true)))
                        
                        (let ((matches (applyRewriteRule graph pattern replacement condition ruleName)))
                          (applyHelper (+ index 1) (+ totalMatches matches))))
                      totalMatches))))
        (applyHelper 0 0)))
    
    ;; Iterate until fixed point or max iterations
    (letrec ((iterate 
              (lambda (iteration)
                (if (>= iteration maxIterations)
                    (println (+ "Reached max iterations (" (i2s maxIterations) ")")); Return value is implicit
                    (let ((matches (applyAllRules exprId rules)))
                      (if (> matches 0)
                          ;; Continue iterating
                          (iterate (+ iteration 1))
                          ;; Fixed point reached
                          0))))))
      
      (iterate 1)
      (extractOGraphSexpr graph exprId))))

;; Prepare rules of this form:
;; (let ((r (rules "Rewrites" (quasiquote ((a => b) (c => d if e))))))
;; (applyRulesUntilFixedPoint expr r 10)
(define (rules namePrefix quotedRules)
  (mapi quotedRules 
        (lambda (i rule)
          (match rule
            ;; Simple rule: a => b
            ((quasiquote (unquote a) => (unquote b)) 
             (list (+ namePrefix " #" (i2s (+ i 1))) 
                   a 
                   b 
                   true))
            
            ;; Conditional rule: c => d if e
            ((quasiquote (unquote c) => (unquote d) if (unquote e)) 
             (list (+ namePrefix " #" (i2s (+ i 1))) 
                   c 
                   d 
                   e))
            
            ;; Default case
            (__ (begin
                  (println (+ "Invalid rule format: " (prettyOrbit rule)))
                  (list
                   (+ namePrefix " invalid #" (i2s (+ i 1)))
                   rule
                   rule
                   true)))))))

(println "Rewrite Library Successfully Loaded")
)