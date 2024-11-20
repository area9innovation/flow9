;;  a9flow-debug-print.el --- A simple addon for a9flow-mode - debug print utilities  -*- lexical-binding:t -*- 

;; Copyright (C) 2024 Evgeniy Turishev

;; Author: Evgeniy Turishev evgeniy.turishev@area9.dk

;; This file is not part of GNU Emacs.

;;; License:

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;;; Commentary:

;; Easy insert debug prints into a9flow code.
;;
;; Copy an indetifier into the kill-ring, move point and use one of a9flow-debug-print-xxx 
;;

(defvar a9flow-debug-print-prefix "##"
  "a prefix to all debug prints")


(defun a9flow-debug-print-var ()
  "Insert debug print of variable from kill-ring"
  (interactive)
  (when kill-ring
    (let ((s (car kill-ring)))
      (insert (format "println(\"%s %s:\" + toString(%s));\n" a9flow-debug-print-prefix s s)))))

(defun a9flow-debug-print-name ()
  "Insert debug print name from kill-ring"
  (interactive)
  (when kill-ring
    (let ((s (car kill-ring)))
      (insert (format "println(\"%s %s\");\n" a9flow-debug-print-prefix s)))))


(defun a9flow-debug-print-map ()
  "Insert debug print (map(arr, \v -> v.id)) from kill-ring"
  (interactive)
  (when kill-ring
    (let ((s (car kill-ring)))
      (insert (format "println(\"%s %s:\" + toString(map(%s, \\vvvvv -> vvvvv.id)));\n" a9flow-debug-print-prefix s s)))))

(defun a9flow-debug-print-transform ()
  "Insert debug print of Transform variable from kill-ring"
  (interactive)
  (when kill-ring
    (let ((s (car kill-ring)))
      (insert (format "println(\"%s %s:\" + toString(fgetValue(%s)));\n" a9flow-debug-print-prefix s s)))))

(defun a9flow-debug-print-subscribe ()
  "Insert debug print of Transform variable from kill-ring"
  (interactive)
  (when kill-ring
    (let ((s (car kill-ring)))
      (insert (format "subscribe(%s, \\vvvvv -> println(\"%s subscribe %s:\" + toString(vvvvv)));\n" s a9flow-debug-print-prefix s)))))


(provide 'a9flow-debug-print)
;;; a9flow-debug-print.el ends here
