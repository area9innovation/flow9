;;  a9flow-debug.el
;; 
;; utilities to debug a9flow code

(provide 'a9flow-debug)

(defun a9flow-insert-dbg-var-print ()
  "Insert debug print of variable from kill-ring"
  (interactive)
  (when kill-ring
    (let ((s (car kill-ring)))
      (insert (format "println(\"## %s:\" + toString(%s));\n" s s)))))

(defun a9flow-insert-dbg-name-print ()
  "Insert debug print name from kill-ring"
  (interactive)
  (when kill-ring
    (let ((s (car kill-ring)))
      (insert (format "println(\"## %s\");\n" s)))))


(defun a9flow-insert-dbg-map-print ()
  "Insert debug print (map(arr, \v -> v.id)) from kill-ring"
  (interactive)
  (when kill-ring
    (let ((s (car kill-ring)))
      (insert (format "println(\"## %s:\" + toString(map(%s, \\vvvvv ->vvvvv.id)));\n" s s)))))

(defun a9flow-insert-dbg-transform-print ()
  "Insert debug print of Transform variable from kill-ring"
  (interactive)
  (when kill-ring
    (let ((s (car kill-ring)))
      (insert (format "println(\"## %s:\" + toString(fgetValue(%s)));\n" s s)))))

(defun a9flow-insert-dbg-subscribe-print ()
  "Insert debug print of Transform variable from kill-ring"
  (interactive)
  (when kill-ring
    (let ((s (car kill-ring)))
      (insert (format "subscribe(%s, \\v -> println(\"## subscribe %s:\" + toString(v)));\n" s s)))))




