;; a9flow-goto.el --- Find symbol definitions using flowc compiler -*- lexical-binding:t -*-

;; Copyright (C) 2024 Evgeniy Turishev

;; Author: Evgeniy Turishev evgeniy.turishev@area9.dk

;; This file is not part of GNU Emacs.

;;; License:

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;;; Commentary:

;; Find symbol definitions using flowc compiler features.
;;
;; find function definition or import file:
;;   M-x a9flow-goto-definition
;;
;; and to return:
;;   M-x a9flow-go-back
;;
;; You have to set a9flow-goto-project-dir (run compiler dir) to the code works.


(defvar a9flow-goto-project-dir nil
  "project directory")

(defvar a9flow-goto-compiler-cmd "flowc1")

(defvar a9flow-goto-find-definition-re "\\([a-zA-Z0-9\-_/:\\\\]+\\.flow\\):\\([0-9]+\\):\\([0-9]+\\):"
  "regexp for parsing result of find-definition compiler invocation")


(defvar a9flow-goto-history '())
(defvar a9flow-goto-cash '())

(defun a9flow-goto-make-find-cmd (word)
  (concat a9flow-goto-compiler-cmd  " find-definition=" word " " (buffer-file-name)))


(defun a9flow-goto-definition ()
  (interactive)
  (a9flow-goto-function-definition))


(defun a9flow-goto-function-definition ()
  (let* ((current-buffer (buffer-name))
	 (current-point (point))
	 (current-position `(,current-buffer ,current-point))
	 (cw (current-word))
	 (hashed-pos (assoc cw a9flow-goto-cash)))
    ;;(message " hash:%s" a9flow-goto-cash)
    (if hashed-pos
	(progn
          (message "a9flow-goto, used cashed entry")
	  (let ((path (nth 1 hashed-pos))
		(pos (nth 2 hashed-pos))
		(content (nth 3 hashed-pos)))

            (find-file path)
            (goto-line pos)

            (let ((new-content (buffer-substring-no-properties (line-beginning-position)
							       (line-end-position))))

	      (if (equal content new-content)
		  (push current-position a9flow-goto-history)
		(progn
		  (message "a9flow-goto, cash entry is invalid, remove: '%s'." cw)
		  (setq a9flow-goto-cash (assq-delete-all cw a9flow-goto-cash))
		  (a9flow-goto-compiled-definition cw current-position))))))

      (a9flow-goto-compiled-definition cw current-position))))


(defun a9flow-goto-compiled-definition (word initial-position)
  (message "a9flow-goto-compiled-definition, word:'%s', position:%s" word initial-position)

  (let ((command-to-execute (a9flow-goto-make-find-cmd word)))
    (message "a9flow-goto-compiled-definition, cmd: '%s'" command-to-execute)
    (let* ((res (shell-command-to-string command-to-execute))
	   (matched-result (string-match a9flow-goto-find-definition-re res)))
      (message "a9flow-goto-compiled-definition, cmd result:'%s'" res)

      (if matched-result
	  (let* ((rel-path (match-string 1 res))
		 (line-num (string-to-number (match-string 2 res)))
		 (column-num  (string-to-number (match-string 3 res))))
	    ;;(message "match:%1 %2 %3" rel-path line-num column-num)

            (find-file rel-path)
            (goto-line line-num)
            (push initial-position a9flow-goto-history)
     
            (let ((line-content (buffer-substring-no-properties (line-beginning-position)
								(line-end-position))))
              (push (list word rel-path line-num line-content) a9flow-goto-cash)))

	(message "Definition not found")))))


(defun a9flow-go-back ()
  (interactive)
  (when (> (length a9flow-goto-history) 0)
    (let* ((position (pop a9flow-goto-history))
	   (b-name (car position))
	   (b-pos (car (cdr position))))

      (switch-to-buffer b-name)
      (goto-char b-pos))))


(defun a9flow-goto-cash-clear ()
  (interactive)
  (setq a9flow-goto-cash nil))


(provide 'a9flow-goto)
;;; a9flow-goto.el ends here

