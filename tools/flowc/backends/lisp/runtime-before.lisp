
(declaim (ftype (function (T) (simple-array character (*)))))

#+ecl
(defun ecl-string-to-octets (str)
  (let ((a (make-array 
             (ceiling (* 1.2 (length str))) ;; initially add 20 % for non-ascii chars
             :element-type '(unsigned-byte 8)
             :adjustable t 
             :fill-pointer 0 )))
    (with-open-stream 
      (stream (ext:make-sequence-output-stream a :external-format :utf-8))
      (format stream str)
      a)))


(defvar flow-struct-names (make-hash-table))

(declaim #+sbcl(sb-ext:muffle-conditions style-warning))
(declaim (optimize (speed 3)))
(defstruct Flow
  ;; (name "" :type (simple-array character (*)) :read-only t)
  (id 0 :type fixnum :read-only t))

(defstruct (Reference (:include Flow))
  (value nil :type t :read-only nil))

(declaim (inline F=))
(declaim (ftype (function (T T) T) F=))
(defun F= (a1 a2)
  (equalp a1 a2))

(declaim (ftype (function (T T) fixnum) Fcompare))

(declaim (ftype (function (* *) fixnum) fl-compare))

(defgeneric fl-compare (a b))
(defmethod fl-compare ((a Flow) (b Flow))
  -1)
(declaim (ftype (function (T) (simple-array character (*))) toString))

(declaim (ftype (function (Flow) (simple-array character (*))) print-flow-object))

(defun print-flow-object (a)
  (declare (optimize (safety 3) (speed 3)))
  (declare (type Flow a))
  (let ((slots #+sbcl(mapcar #'sb-mop:slot-definition-name
			     (sb-mop:class-direct-slots (class-of a)))
	       #+ecl(mapcar #'clos:slot-definition-name
			    (clos:class-direct-slots (class-of a)))))
    (let* ((fields (loop
		     for slot in slots
		      collect (toString (slot-value a slot))))
	   (len (list-length fields)))
      
      (~
       (~ (first (gethash (flow-id a) flow-struct-names)) "(")
       (~ (reduce #'~
		  (loop
		     for i fixnum from 0
		     for x in fields
		     collect (if (< i (1- len))
				 (~ x ", ")
				 x))) ")")))))

(defun mk-array (&optional (array nil))
  (let* ((len (list-length array))
	 (res (make-array len
			  ;; :element-type 
			  :fill-pointer nil
			  :adjustable nil
			  :initial-contents array)))
    res))

(defun Fcompare (a1 a2)
  (cond
    ((floatp a1) (cond
		   ((< (the double-float a1) (the double-float a2)) -1)
		   ((= (the double-float a1) (the double-float a2))  0)
		   (T 1)))
    ((integerp a1) (cond
		     ((< (the fixnum a1) (the fixnum a2)) -1)
		     ((= (the fixnum a1) (the fixnum a2))  0)
		     (T 1)))
    ((stringp a1) (cond
		    ((string< (the (simple-array character (*)) a1) (the (simple-array character (*)) a2)) -1)
		    ((string= (the (simple-array character (*)) a1) (the (simple-array character (*)) a2))  0)
		    (T 1)))
    ((and (arrayp a1)
    	  (arrayp a2)) (if (= (length a1) (length a2))
    			   (let ((mm (mismatch a1 a2 :test #'F=)))
    			     (if (null mm)
    				 0
    				 (let ((mi mm))
    				   (declare (type fixnum mi))
    				   (Fcompare (svref (the (simple-array * (*)) a1) mi)
    					     (svref (the (simple-array * (*)) a2) mi)))))
    			   -1))
    ((typep a1 'Flow) (sb-ext:truly-the fixnum (fl-compare a1 a2)))
    (T (cond
	 ((equalp a1 a2) 0)
	 (T -1)))))

(declaim (inline F<))
(defun F< (a1 a2)
  (= (the fixnum (Fcompare a1 a2)) -1))

(declaim (inline F>))
(defun F> (a1 a2)
  (= (the fixnum (Fcompare a1 a2)) 1))

(declaim (inline F<=))
(defun F<= (a1 a2)
  (< (the fixnum (Fcompare a1 a2)) 1))

(declaim (inline F>=))
(defun F>= (a1 a2)
  (>= (the fixnum (Fcompare a1 a2)) 0))

(declaim (ftype (function ((simple-array character (*)) (simple-array character (*))) (simple-array character (*))) ~))
(defun ~ (s1 s2)
  (concatenate 'string s1 s2))

(defun is-of (struct type)
  (eql (find-class type) (class-of struct)))

(defmacro defalias (to fn)
  `(setf (fdefinition ',to) #',fn))

(declaim (ftype (function ((simple-array * (*)) (simple-array * (*))) (simple-array * (*))) concatNative))
(defun concatNative (a1 a2)
  (concatenate 'vector a1 a2))

(defun lengthNative (a)
  (declare (type (simple-array * (*)) a))
  (length a))

(defun toString (value)
  (declare (optimize (speed 0)))
  (cond
    ((is-of value 'Reference) (~ (the (simple-array character (*)) "ref ")
				 (toString (reference-value value))))
    ((integerp value) (map '(simple-array character (*))
			   #'identity
			   (mapcar #'(lambda (x) (coerce x 'character))
				   (coerce (write-to-string value) 'list)))
     )
    ((stringp value) (the (simple-array character (*)) (~ "\"" (~ value "\""))))
    ((arrayp value) (map '(simple-array character (*))
			   #'identity
			   (mapcar #'(lambda (x) (coerce x 'character))
				   (coerce (write-to-string (format nil "[~{~A~^, ~}]"
			    (loop
			       for x across value
			       collect (toString x)))) 'list)))
     )
    ((subtypep (type-of value) 'Flow) (print-flow-object value))
    (t (format nil "~A" value))))


(defun fcPrintln2Native (value)
  (princ (format nil "~A~%"
		 (if (stringp value)
		     value
		     (toString value))))
  nil)

(defun isSameStructTypeNative (a b)
  (eql (find-class a) (find-class b)))

(declaim (inline foldNative))
(defun foldNative (arr init fn)
  (reduce fn arr :initial-value init))

#+sbcl(require :sb-md5)
#+ecl (require 'ecl-quicklisp)
#+ecl (ql:quickload "md5")
(defun md5Native (str)
  (string-downcase
   (reduce #'(lambda (a b)
	       (concatenate '(simple-array character (*)) a b))
	   (let ((st #+sbcl(sb-md5:md5sum-string str)
		     #+ecl (md5:md5sum-string str)))
	     (declare (type (simple-array (unsigned-byte 8) (*)) st))
	     (loop for x across st
		collecting (format nil "~2,'0x" x)))
	   :initial-value "")))

(defun getAllUrlParametersNative ()
  #(
    #("file" "tools/flowc/flowc.flow") #("lisp" "al.lisp") #("bytecode" "al.bytecode") #("verbose" "0")
    ;;#("file" "sandbox/helloworld.flow") #("lisp" "hw.lisp") #("bytecode" "hw.bytecode") #("verbose" "0")
    ;;#("file" "sandbox/fun.flow") #("lisp" "fun.lisp") #("bytecode" "fun.bytecode") #("verbose" "0")
    ;;#("file" "mini.flow") #("bytecode" "mini.bytecode") #("dce" "0")
    )
  ;; (let* ((line (rest sb-ext:*posix-argv*)))
  ;;   (map 'vector
  ;; 	 #'(lambda (x)
  ;; 	     (let* ((val x)
  ;; 		    (p (position #\= val)))
  ;; 	       (if p
  ;; 		   (make-array 2 :initial-contents (list (subseq val 0 p) (subseq val (1+ p))) :fill-pointer nil :adjustable nil)
  ;; 		   (make-array 1 :initial-contents (list val) :fill-pointer nil :adjustable nil))))
  ;; 	 line))
  )

(defun getTargetNameNative ()
  "lisp")

(defun loaderUrlNative()
  "")

(defun elemIndexNative (arr elem illegal)
  (declare (optimize (safety 0) (speed 3))
	   (type (simple-vector *) arr))
  (let ((res (position elem arr :test #'F=)))
    (if res res illegal)))

(defun quitNative (code)
  (princ (format nil "Quit issued~%"))
  ;;#+cormanlisp (ccl:lisp-shutdown (write-to-string code))
  ;;#+sbcl(sb-ext:exit :code code)
  ;;#+ccl (ccl:quit code)
  ;;#+ecl (ext:quit code)
  )

(declaim (ftype (function (fixnum fixnum) (simple-vector *))))

(defun enumFromToNative (from to)
  (declare (type fixnum from to))
  (declare (optimize (safety 1) (speed 3)))
  (let ((n (1+ (the fixnum (- to from)))))
    (declare (type fixnum n))
    (if (< n 0)
	(make-array 0 :element-type T :adjustable nil :initial-contents nil :fill-pointer nil)
	(let ((res (make-array n :element-type T :adjustable nil :fill-pointer nil)))
	  (dotimes (i n)
	    (declare (type fixnum i))
	    (setf
	     (svref res i)
	     (the fixnum (+ i from))))
	  res))))

(defun existsNative (arr fn)
  (declare (optimize (safety 0) (speed 3))
	   (type (simple-vector *) arr)
	   (type (function (T) T) fn))
  (let ((res (find-if fn arr)))
    (if res T NIL)))

(defun filterNative (arr test)
  (declare (optimize (safety 0) (speed 3))
	   (type (simple-array * (*)) arr))
  (remove-if-not test arr))

;;(declaim (ftype (function ((simple-array * (*)) T (function (fixnum T T))) T) foldiNative))

(defun foldiNative (arr init fn)
  (declare (type (simple-array * (*)) arr)
	   (type (function (fixnum T T) T) fn))
  (let ((res init))
    (dotimes (i (length arr))
      (setf res (funcall fn i res (svref arr i))))
    res))

;;(declaim (ftype (function ((simple-array * (*)) (function (T) T)) (simple-array * (*))) mapNative))

(defun mapNative (arr fn)
  (declare (type (simple-vector *) arr)
	   (type (function (T) T) fn))
  (map '(simple-vector *) fn arr))

(defun mapiNative (arr fn)
  (declare (type (simple-vector *) arr)
	   (type (function (fixnum T) T) fn))
  (let ((res (make-array (array-dimensions arr)
			 :fill-pointer nil
			 :adjustable nil)))
    (loop
       for i fixnum from 0
       for x across arr
       do (setf (svref res i) (funcall fn i x)))
    res))

(defun iterNative (arr fn)
  (declare (type (simple-vector *) arr)
	   (type (function (T) *) fn))
  (loop
     for x across arr
     do (funcall fn x))
  nil)

(defun iteriNative (arr fn)
  (declare (type (simple-vector *) arr)
	   (type (function (fixnum T) *) fn))
  (loop
     for x across arr
     for i fixnum from 0
     do (funcall fn i x))
  nil)

(defun iteriUntilNative (arr fn)
  (declare (type (simple-vector *) arr)
	   (type (function (fixnum T) *) fn))
  (loop
     for i fixnum from 0
     for x across arr
     if (funcall fn i x)
     do (return-from iteriUntilNative i))
  (length arr))

(defun replaceNative (arr pos elem)
  (declare (type (simple-vector *) arr)
	   (type fixnum pos))
  (when (< pos 0)
    (return-from replaceNative #()))
  ;;(break "~A" arr)
  (let* ((alen (length arr))
	 (len (if (> alen pos) alen (1+ pos)))
	 (res (make-array len
			  :fill-pointer nil
			  :element-type T
			  :adjustable nil)))
    (declare (type fixnum alen len))
    (replace res arr)
    (setf (svref res pos) elem)
    res))

(defun subrangeNative (arr start len)
  (declare (type (simple-array * (*)) arr)
	   (type fixnum start len))
  ;;// Make sure we are within bounds
  ;;if (start < 0 || len < 1 || start >= arr.length) return new Object[0];
  ;;len = clipLenToRange(start, len, arr.length);
  ;;return Arrays.copyOfRange(arr, start, start + len);
  (let ((alen (length arr)))
    (when (or (< start 0)
	      (< len 1)
	      (>= start alen))
      (return-from subrangeNative #()))
    (let ((len (cliplentorange start len alen)))
      (declare (type fixnum len))
      (subseq arr start (+ start len)))))

(declaim (ftype (function (fixnum fixnum) fixnum) bitAndNative)
	 (ftype (function (fixnum fixnum) fixnum) bitOrNative)
	 (ftype (function (fixnum fixnum) fixnum) bitXorNative)
	 (ftype (function (fixnum fixnum) fixnum) bitShlNative)
	 (ftype (function (fixnum fixnum) fixnum) bitUshrNative)
	 (ftype (function (fixnum) fixnum) bitNotNative))

(defun bitAndNative (a b)
  (declare (type fixnum a b))
  (logand a b))

(defun bitOrNative (a b)
  (declare (type fixnum a b))
  (logior a b))

(defun bitXorNative (a b)
  (declare (type fixnum a b))
  (logxor a b))

(defun bitNotNative (a)
  (declare (type fixnum a))
  (lognot a))

(defun bitShlNative (a n)
  (declare (optimize (speed 0))
	   (type fixnum a n))
  (ash a n))

(defun bitUshrNative (a n)
  (declare (optimize (speed 0))
	   (type fixnum a n))
  (ash a (- n)))

(defun failWithErrorNative (msg)
  (princ (format nil "~A~%" msg))
  (quitNative 0))

(defun getApplicationPathNative ()
  "")

(defun getFileContentNative (fname)
  (declare (type string fname))
  (handler-case
       (let ((fc (with-open-file (s fname :direction :input :if-does-not-exist :error :element-type '(unsigned-byte 8))
		   (let* ((len (file-length s))
			  (buffer (make-array len
					      :element-type '(unsigned-byte 8)
					      :adjustable nil
					      :fill-pointer nil)))
		     (read-sequence buffer s)
		     #+ecl (ecl-string-to-octets buffer)
		     #+sbcl(sb-ext:octets-to-string buffer :external-format :utf-8)))))
	 (if fc fc ""))
    (error () "")))

(defun hostCallNative (name args)
  (declare (ignore name args))
  nil)

(defun string2utf8Native (string)
  (declare (type (simple-array character (*)) string))
  (mk-array (map 'list
			#'identity
			#+ecl (ecl-string-to-octets string)
			#+sbcl(sb-ext:string-to-octets string :external-format :utf8))))

(defun fast_maxNative (a b)
  (if (F> a b) a b))

(defun fcPrintlnNative (value)
  (princ (format nil "~A~%" value)))

(defun setFileContentNative (fname content)
  (declare (type string fname content))
  (let ((cnt
	 #+ecl (ecl-string-to-octets content)
	 #+sbcl(sb-ext:string-to-octets content :external-format :utf8)))
    (with-open-file (s fname
		       :direction :output
		       :if-does-not-exist :create
		       :if-exists :supersede
		       :element-type '(unsigned-byte 8))
      (write-sequence cnt s)))
  t)
(declaim (ftype (function () double-float) timestampNative))
(defun timestampNative ()
  (declare (optimize (speed 1)))
  #+ccl(/ (ccl:current-time-in-nanoseconds) 100.0D0)
  #+ecl(get-internal-real-time)
  #+sbcl(multiple-value-bind (sec usec)
	    (sb-ext:get-time-of-day)
	  (let ((res (* (+ (* (coerce usec 'double-float) 1.0D-6)
			   (coerce sec 'double-float))
			1000.0D0)))
	    (declare (type double-float res))
	    res)))

(defun fromCharCodeNative (code)
  (declare (type fixnum code))
  (string (code-char code)))

(declaim (ftype (function (string fixnum) fixnum) getCharCodeAtNative))
(defun getCharCodeAtNative (string pos)
  (declare (type (simple-array character (*)) string)
	   (type fixnum pos))
  (if (<= 0 pos (1- (length string)))
      (char-code (elt string pos))
      -1))

(defun s2aNative (string)
  (declare (type (simple-array character (*)) string))
  (let ((a (make-array (length string)
		       :element-type T
		       :fill-pointer nil
		       :adjustable nil)))
    (loop for char across string
       for i fixnum from 0
       do (setf (svref a i) (char-code char)))
    a))

(defun strIndexOfNative (string substring)
  (declare (type (simple-array character (*)) string substring))
  (let ((res (search substring string)))
    (declare (type (or null fixnum) res))
    (if res res -1)))

(defun strRangeIndexOfNative (string substring start end)
  (declare (type fixnum start end)
	   (type (simple-array character (*)) string substring))
  (let* ((ln (length string))
	 (res (search substring
		      string
		      :start2 (max 0 (min start ln))
		      :end2 (min end (max 0 ln)))))
    (declare (type (or null fixnum) res))
    (if res res -1)))

(declaim (ftype (function (string) fixnum) strLenNative))
(defun strLenNative (string)
  (length string))

(defun clipLenToRange (start len size)
  (declare (type fixnum start len size))
  (let* ((len len)
	 (end (+ start len)))
    (declare (type fixnum len end))
    (if (or (> end size) (< end 0))
	(setf len (- size start)))
    len))

(defun substringNative (string start length)
  (declare (type fixnum start length)
	   (type (string) string))
  (let ((strlen (length string))
  	(len length)
	(start start))
    (declare (type fixnum strlen len start))
    (when (< len 0)
      (if (< start 0)
  	  (setf len 0)
  	  (let ((smartLen2 (+ len start)))
	    (if (<= smartLen2 0)
		(setf len 0)
		(setf len smartLen2)))))
    (if (< start 0)
	(let ((smartStart (+ strlen start)))
	  (if (> smartStart 0)
	      (setf start smartStart)
	      (setf start 0)))
	(when (>= start strlen)
	  (setf len 0)))
    (if (< len 1)
	""
	(progn
	  (setf len (clipLenToRange start len strlen))
	  (subseq string start (+ start len))))))

(defun toLowerCaseNative (string)
  (declare (type (string) string))
  (string-downcase string))

(defun toUpperCaseNative (string)
  (declare (type (string) string))
  (string-upcase string))

;; Helper filesystem functions
(defun component-present-p (value)
  (and value (not (eql value :unspecific))))

(defun directory-pathname-p  (p)
  (and
   (not (component-present-p (pathname-name p)))
   (not (component-present-p (pathname-type p)))
   p))

(defun pathname-as-directory (name)
  (declare (optimize (speed 1)))
  (let ((pathname (pathname name)))
    (when (wild-pathname-p pathname)
      (error "Can't reliably convert wild pathnames."))
    (if (not (directory-pathname-p name))
      (make-pathname
       :directory (append (or (pathname-directory pathname) (list :relative))
                          (list (file-namestring pathname)))
       :name      nil
       :type      nil
       :defaults pathname)
      pathname)))

(defun directory-wildcard (dirname)
  (make-pathname
   :name :wild
   :type :wild
   :defaults (pathname-as-directory dirname)))

(defun list-directory (dirname)
  (when (wild-pathname-p dirname)
    (error "Can only list concrete directory names."))
  #+:ecl
  (let ((dir (pathname-as-directory dirname)))
    (concatenate 'list
                 (directory (merge-pathnames (pathname "*/") dir))
                 (directory (merge-pathnames (pathname "*.*") dir))))
  #-:ecl
  (directory (directory-wildcard dirname)))

(defun createDirectoryFlowFileSystem (dir)
  (ensure-directories-exist (pathname-as-directory dir))
  "")

(defun deleteDirectoryFlowFileSystem (dir)
  (if (probe-file (pathname-as-directory dir))
      #+ecl ""
      #+sbcl(sb-ext:delete-directory dir :recursive t)
      "")
  "")

(defun deleteFileFlowFileSystem (file)
  (handler-case
      (with-open-file (s file :if-does-not-exist :error)
	(delete-file s)
	"")
    (error () "")))

(defun fileExistsFlowFileSystem (file)
  (probe-file file))

(defun fileModifiedFlowFileSystem (file)
  (declare (optimize (speed 1)))
  (handler-case
      (with-open-file (s file :if-does-not-exist :error)
	(coerce (file-write-date s)
		'double-float))
    (error () 0.0D0)))

(defun isDirectoryFlowFileSystem (file)
  (not (null (directory-pathname-p (probe-file file)))))

(defun readDirectoryFlowFileSystem (dir)
  (map 'vector
       #'(lambda (x)
	   (let ((dir (pathname-directory x))
		 (name (pathname-name x))
		 (ext (pathname-type x)))
	     (if (and (null name) (null ext))
		 (car (last (rest dir)))
		 (~ (if name name "") (if ext (~ "." ext) "")))))
       (list-directory (pathname-as-directory dir))))

(defun resolveRelativePathFlowFileSystem (file)
  (declare (optimize (speed 1)))
  (declare (type (simple-array character (*)) file))
  (let ((pf (probe-file file)))
    (coerce (if pf
		(or (namestring pf)) file)
	     '(simple-array character (*)))))

(defun setFileContentBytesNative (file content)
  (declare (type (simple-array character (*)) file content)
	   (optimize (speed 3)))
  (let ((cnt
	 (map '(simple-array (unsigned-byte 8) (*))
	      #'identity
	      (mapcar #'(lambda (x)
			  (coerce (logand (char-code x) 255)
				  '(unsigned-byte 8)))
		      (coerce content 'list)))))
    (declare (type (simple-array (unsigned-byte 8) (*)) cnt))
    (with-open-file (s file
		       :direction :output
		       :if-does-not-exist :create
		       :if-exists :supersede
		       :element-type '(unsigned-byte 8))
      (write-sequence cnt s)))
  t)

(defun startProcessNative (command args cwd stdin onExit))

(defun toBinaryNative (value)
  (let ((res "NATIVE"))
    (declare (type (simple-array character (*))))
    res))

(declaim (ftype (function (double-float) (simple-vector *)) double2bytes))
(defun double2bytes (d)
  (let* ((a (loop
	       for i from 0 to 3
	       collect (logand (ash (sb-kernel:double-float-low-bits d)
				    (* 8 (- i)))
			       #xFF)))
	 (b (loop
	       for i from 0 to 3
	       collect (logand (ash (sb-kernel:double-float-high-bits d)
				    (* 8 (- i)))
			       #xFF)))
	 (lst (list (logior (ash (nth 1 a) 8) (nth 0 a))
		    (logior (ash (nth 3 a) 8) (nth 2 a))
		    (logior (ash (nth 1 b) 8) (nth 0 b))
		    (logior (ash (nth 3 b) 8) (nth 2 b)))))
    (map '(simple-vector *) #'identity (concatenate 'list a b))
    ;;(coerce (mapcar #'code-char lst) '(simple-array character (*)))
    ))

