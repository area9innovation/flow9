// Array utility functions for SEXP
(
  // map: Apply a function to each element in an array
  (define map (lambda (arr f)
    (if (= (length arr) 0)
      (list)
      (concat (list (f (index arr 0))) (map (subrange arr 1 (- (length arr) 1)) f)))))

  // filter: Keep only elements that match a predicate
  (define filter (lambda (arr pred)
    (if (= (length arr) 0)
      (list)
      (if (pred (index arr 0))
        (concat (list (index arr 0)) (filter (subrange arr 1 (- (length arr) 1)) pred))
        (filter (subrange arr 1 (- (length arr) 1)) pred)))))

  // fold: Accumulate a result based on each array element and an accumulator
  (define fold (lambda (arr init f)
    (if (= (length arr) 0)
      init
      (fold (subrange arr 1 (- (length arr) 1)) (f init (index arr 0)) f))))

  // mapi: Map with index
  (define mapi (lambda (arr f)
    (define mapiHelper (lambda (arr f idx)
      (if (= (length arr) 0)
        (list)
        (concat (list (f idx (index arr 0))) (mapiHelper (subrange arr 1 (- (length arr) 1)) f (+ idx 1))))))
    (mapiHelper arr f 0)))

  // filteri: Filter with index
  (define filteri (lambda (arr pred)
    (define filteriHelper (lambda (arr pred idx)
      (if (= (length arr) 0)
        (list)
        (if (pred idx (index arr 0))
          (concat (list (index arr 0)) (filteriHelper (subrange arr 1 (- (length arr) 1)) pred (+ idx 1)))
          (filteriHelper (subrange arr 1 (- (length arr) 1)) pred (+ idx 1))))))
    (filteriHelper arr pred 0)))

  // foldi: Fold with index
  (define foldi (lambda (arr init f)
    (define foldiHelper (lambda (arr acc f idx)
      (if (= (length arr) 0)
        acc
        (foldiHelper (subrange arr 1 (- (length arr) 1)) (f idx acc (index arr 0)) f (+ idx 1)))))
    (foldiHelper arr init f 0)))

  // tail: Return all elements except the first one
  (define tail (lambda (arr)
    (if (<= (length arr) 1)
      (list)
      (subrange arr 1 (- (length arr) 1)))))

  // tailFrom: Return all elements from a given index to the end
  (define tailFrom (lambda (arr idx)
    (if (>= idx (length arr))
      (list)
      (subrange arr idx (- (length arr) idx)))))

  // take: Return the first n elements of an array
  (define take (lambda (arr n)
    (if (<= n 0)
      (list)
      (if (= (length arr) 0)
        (list)
        (concat (list (index arr 0)) (take (subrange arr 1 (- (length arr) 1)) (- n 1)))))))

  // contains: Check if an element exists in the array
  (define contains (lambda (arr element)
    (if (= (length arr) 0)
      false
      (if (= (index arr 0) element)
        true
        (contains (subrange arr 1 (- (length arr) 1)) element)))))

  // exists: Check if any element satisfies a predicate
  (define exists (lambda (arr pred)
    (if (= (length arr) 0)
      false
      (if (pred (index arr 0))
        true
        (exists (subrange arr 1 (- (length arr) 1)) pred)))))

  // forall: Check if all elements satisfy a predicate
  (define forall (lambda (arr pred)
    (if (= (length arr) 0)
      true
      (if (not (pred (index arr 0)))
        false
        (forall (subrange arr 1 (- (length arr) 1)) pred)))))

  // push an element to the end of an array
  (define arrayPush (lambda (arr elem)
    (concat arr (list elem))))

  // Remove first occurrence of an element
  (define removeFirst (lambda (arr element)
    (define removeFirstHelper (lambda (before after)
      (if (= (length after) 0)
        before
        (if (= (index after 0) element)
          (concat before (subrange after 1 (- (length after) 1)))
          (removeFirstHelper (concat before (list (index after 0))) (subrange after 1 (- (length after) 1)))))))
    (removeFirstHelper (list) arr)))

  // Remove an element at specific index
  (define removeIndex (lambda (arr idx)
    (if (< idx 0)
      arr
      (if (>= idx (length arr))
        arr
        (concat (take arr idx) (tailFrom arr (+ idx 1)))))))

  // Reverse an array
  (define reverse (lambda (arr)
    (define reverseHelper (lambda (arr acc)
      (if (= (length arr) 0)
        acc
        (reverseHelper (tail arr) (concat (list (index arr 0)) acc)))))
    (reverseHelper arr (list))))
)