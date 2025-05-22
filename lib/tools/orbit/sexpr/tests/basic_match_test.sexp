// Very basic test for pattern matching

(define x 5)

(println "Basic pattern matching:")
(println (match x
  (5 "five")
  (10 "ten")
  (_ "other")))

(define y 10)
(println (match y
  (5 "five")
  (10 "ten")
  (_ "other")))

(define z 15)
(println (match z
  (5 "five")
  (10 "ten")
  (_ "other")))