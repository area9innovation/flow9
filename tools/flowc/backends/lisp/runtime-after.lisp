;; Lisp runtime after structs

(defun list2arrayNative (list)
  (declare (optimize (speed 3) (safety 0)))
  (cond
    ((null list) #())
    ((= (flow-id list) 13) #())
    ((= (flow-id list) 12) (let* ((c (loop
					for cnt fixnum from 0
					for i = list
					then (fl0wCons-ffl0wtail i)
					while (= (flow-id i) 12) ;; Cons id
					finally (return cnt)))
				  (res (make-array c
						   :fill-pointer nil
						   :adjustable nil)))
			      (loop
				 for cnt fixnum from 0
				 for i = list
				 then (fl0wCons-ffl0wtail i)
				 while (= (flow-id i) 12) ;; Cons id
				 do (setf (aref res (- c cnt 1)) (fl0wCons-fhead i)))
			      res))
    (T #())))

(defun list2stringNative (list)
  (declare (optimize (speed 3) (safety 0)))
  (cond
    ((null list) "")
    ((= (flow-id list) 13) "")
    ((= (flow-id list) 12) (let* ((c 0)
				  (res "")
				  (idx 0))
			     (declare (type fixnum idx)
				      (type fixnum c)
				      (type string res))
			     (loop
				for cnt fixnum from 0
				for i = list
				then (fl0wCons-ffl0wtail i)
				while (= (flow-id i) 12) ;; Cons id
				do (incf c (length (the string (fl0wCons-fhead i)))))
			     (setf res (make-string c))
			     (loop
				for cnt fixnum from 0
				for i = list
				then (fl0wCons-ffl0wtail i)
				while (= (flow-id i) 12) ;; Cons id
				do (let ((str (the (simple-array character (*)) (fl0wCons-fhead i))))
				     (replace res str :start1 (- c (length str)))
				     (decf c (length str))))
			     res))
    (T "")))



