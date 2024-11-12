;; a9flow-goto.el
;; 
;; Find symbol definitions using flowc compiler features.
;;
;; Author: Evgeniy Turishev evgeniy.turishev@area9.dk
;; This module based on original a9flow-mode Nikolay Sokolov <Nikolay.Sokolov@area9.dk>
;;
;; This file is not part of GNU Emacs.
;;
;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; find function definition or import file:
;; M-x a9flow-goto-definition
;; and
;; M-x a9flow-go-back
;;
;; you have to set a9flow-goto-project-dir (run compiler dir) to this module works

(provide 'a9flow-goto)

(defvar a9flow-goto-project-dir nil "a9flow default directory")

(defvar a9flow-goto-history '())
(defvar a9flow-goto-hash '())


(defun a9flow-find-file-in-include-paths (fname)
;;  (message "find name '%s' in includes:%s" fname a9flow-include-list)
  (let ((dir (seq-find
	      (lambda (dir) (file-exists-p (concat a9flow-goto-project-dir "/" dir "/" fname)))
	      a9flow-include-list)))
    (message "found '%s' in dir '%s'" fname dir)
    (if dir (concat a9flow-goto-project-dir "/"  dir "/" fname) nil)))


(defun a9flow-goto-function-definition ()
  (interactive)
  (setq current-buffer (buffer-name))
  (setq current-point (point))
  (setq current-position `(,current-buffer ,current-point))
  (setq cw (current-word))
  (setq hashed-pos (assoc cw a9flow-goto-hash))
  (if hashed-pos
      (progn
        (message "Found hashed destination")
        (setq path (nth 1 hashed-pos))
        (setq pos (nth 2 hashed-pos))
        (setq content (nth 3 hashed-pos))
        (find-file path)
        (goto-line pos)
        (setq new-content (buffer-substring-no-properties (line-beginning-position) (line-end-position)))
        (if (equal content new-content)
            (push current-position a9flow-goto-history)
          (progn
            (message
             (concat
              "Hash destination changed.\nPath: " path
              "\nOld line num: " (number-to-string line-num)
              "\nOld value: " content
              "\nNew value: " new-content))
            (assq-delete-all cw a9flow-goto-hash)
            (goto-char 0)
            (if (search-forward content nil t 1)
                (progn
                  (push `(,cw ,path ,(line-number-at-pos) ,content) a9flow-goto-hash)
                  (push current-position a9flow-goto-history))
              (let ((default-directory a9flow-basedir))
                (a9flow-goto-compiled-definition cw current-buffer current-point))))))
    (a9flow-goto-compiled-definition cw current-buffer current-point))

    )

(defun a9flow-import-line ()
  (let ((cv (buffer-substring-no-properties (line-beginning-position) (line-end-position))))
    (when (string-match "import[ \t]+\\(.*\\);" cv) (match-string 1 cv))))

(defun a9flow-goto-definition ()
  (interactive)
  (let ((import-decl (a9flow-import-line)))
    (message "a9flow-goto-definition:%s" import-decl)
    (if import-decl
	(a9flow-goto-import-intern import-decl)
      	(a9flow-goto-function-definition))))

(defun a9flow-goto-import ()
  (interactive)
  (let (import-decl (a9flow-import-line))
    (if import-decl
	(a9flow-goto-import-intern import-decl)
      (message "error: is not import line"))))

(defun a9flow-goto-import-intern (import-decl)
  (setq current-position `(,(buffer-name) ,(point)))
  (push current-position a9flow-goto-history)
  (let ((proj (a9flow-proj-find a9flow-default-target)))
	(let ((fname (concat import-decl ".flow"))
	      (tmp-history a9flow-goto-history))
	  (message "goto import:%s" import-decl)
	  (let ((proj-file (concat a9flow-goto-project-dir "/" fname)))
	    (if (file-readable-p proj-file)
		(find-file proj-file)
	      (let ((lib-path (concat a9flow-goto-project-dir "/" a9flow-flow-directory "/lib/" fname)))
		(message "import from lib:%s" lib-path)
		(if (file-readable-p lib-path)
		    (find-file lib-path)
		  (let ((f (a9flow-find-file-in-include-paths fname)))
		    (if f (find-file f) (message "file '%s' is not readable or not exists" fname))))))
	    (setq a9flow-goto-history tmp-history)))
      ))


(defun a9flow-goto-compiled-definition(word initial-buffer initial-point)
  (message "word%s; buffer:%s; point:%s; dir:%s" word  (buffer-file-name) initial-point a9flow-goto-project-dir)
  (setq a9flow-compiler-path "flowc1")
  (setq command-to-execute (concat a9flow-compiler-path  " find-definition=" word " " (buffer-file-name)))
  (message command-to-execute)
  (setq res (shell-command-to-string command-to-execute))
  (message "cmd result:%s" res)
  (setq matched-result (string-match "\\([a-zA-Z0-9\-_/:\\\\]+\\.flow\\):\\([0-9]+\\):\\([0-9]+\\):" res))
  (if matched-result
      (progn
	;;(message "match:%1 %2 %3" (match-string 1 res) (match-string 2 res) (match-string 3 res))
        (setq rel-path (match-string 1 res))
        (setq line-num (string-to-number (match-string 2 res)))
	(setq column-num  (string-to-number (match-string 3 res)))
        (find-file rel-path)
        (goto-line line-num)
        (setq line-content (buffer-substring-no-properties (line-beginning-position) (line-end-position)))
        (push current-position a9flow-goto-history)
        (push `(,cw ,rel-path ,line-num ,line-content) a9flow-goto-hash))
    (progn
      (message (concat "Error: " res))
      (switch-to-buffer initial-buffer)
      (goto-char initial-point))))

(defun a9flow-go-back ()
  (interactive)
  (when (> (length a9flow-goto-history) 0)
    (setq position (pop a9flow-goto-history))
    (setq b-name (car position))
    (setq b-pos (car (cdr position)))
    (switch-to-buffer b-name)
    (goto-char b-pos)))

(defun a9flow-goto-hash-clear ()
  (interactive)
  (setq a9flow-goto-hash nil))

(defun a9flow-goto-hash-save ()
  (setq a9flow-goto-hash nil))

(defun a9flow-history-point ()
  (interactive)
  (setq current-position `(,(buffer-name) ,(point)))
  (push current-position a9flow-goto-history))


