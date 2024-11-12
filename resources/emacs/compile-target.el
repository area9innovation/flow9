;; compile-target.el 
;;
;; A simple project management minor mode.
;;
;; Author: Evgeniy Turishev evgeniy.turishev@area9.dk
;;
;; This file is not part of GNU Emacs.
;;
;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; It manages a list of targets (names) with corresponed command lines 
;; to open project:
;; M-x compile-target-open-project 
;;
;; After that, all commands will run in a project directory (where a project file is placed).
;;
;; Project is ordinary elisp file with sequence of compile-target-add calls.
;; (compile-target-add "short-name" "a/command/line/to/run -with -many -options")
;; It allow also to add any elisp stuff to adjust your project.
;; 
;; You can set compile-target-after-open-project hook to catch select project events, to get project directory and so on:
;; (setq compile-target-after-open-project (lambda (project-file) ...))
;;
;; Use ivy or ido to use it with more comfort.  
;; M-x compile-target-compile-ivy
;; M-x compile-target-compile-ido
;;
;; compile last used target or first in targets list 
;; M-x compile-target-compile-default 


(require 'cl-lib)
(require 'compile)
(provide 'compile-target)


(defvar compile-target-project-file nil "Current project file name")
(defvar compile-target-proj-default-directory nil "compile-target default directory")
(defvar compile-target-target-list () "compile-target targets list")
(defvar compile-target-default-target nil "compile-target default target")

(defvar compile-target-after-open-project nil)
  
(defun compile-target-add (name compile-cmd)
  "Add target to (or replace in) the tragets list"
  (interactive "sName:\nsCommand:")
  (if (stringp name)
      (progn
	(setq compile-target-default-target name)
	(setq compile-target-target-list
	      (cons (list
		     'name name
		     'compile-cmd compile-cmd)
		    (cl-delete name compile-target-target-list
			       :test 'equal
			       :key (lambda (proj) (plist-get proj 'name))))))
    (message "load project error: name:'%s'" name)))

(defun compile-target-clear-target-list ()
 "Clear target list"
  (interactive)
  (setq compile-target-target-list nil))


(defun compile-target-proj-find (target-name)
  (cl-find target-name compile-target-target-list :test 'equal :key (lambda (proj) (plist-get proj 'name))))


(defun compile-target-open-project (project-file-name)
  "Load project file"
  (interactive	"fProject file: ")
  (setq compile-target-project-file project-file-name)
  (setq compile-target-proj-default-directory (file-name-directory project-file-name))
  (message "compile-target project:%s" project-file-name)
  (message "compile-target default dir:%s" compile-target-proj-default-directory)
  (load-file project-file-name)
  (when (functionp compile-target-after-open-project)
    (funcall compile-target-after-open-project project-file-name)
    ))


(defun compile-target-compile-ido ()
  (interactive)
  (if (fboundp 'ido-completing-read)
      (progn
        (setq target-name (ido-completing-read "Compile target: " (mapcar 'cadr compile-target-target-list)))
        (compile-target-compile target-name))
    (message "ido not found")))


(defun compile-target-compile-ivy ()
  (interactive)
  (if (fboundp 'ivy-read)
      (progn
        (setq target-name (ivy-read "Compile target: " (mapcar 'cadr compile-target-target-list)))
        (compile-target-compile target-name))
    (message "ivy not found")))



(defun compile-target-compile (target-name)
  "Compile project's target"
  (interactive	"sTarget name: ")
  (let ((proj (compile-target-proj-find target-name)))
    (if proj
	(let (
	      (compile-cmd (plist-get proj 'compile-cmd))
	      (work-dir (plist-get proj 'work-dir))
	      (curr-dir default-directory)
	      )
	  (setq compile-target-default-target target-name)	  
	  (cd compile-target-proj-default-directory)
	  (compile compile-cmd)
	  (cd curr-dir)
	  )
      (message "Target '%s' not found" target-name))))


(defun compile-target-compile-default ()
  "Compile default target"
  (interactive)
  (compile-target-compile compile-target-default-target))


(defvar compile-target-mode-map
  (let ((map (make-sparse-keymap)))
    map)
  "Map for `compile-target-mode`")


;;;###autoload
(define-minor-mode compile-target-mode
  "simple helper that allow to select compilation target from a list"
  :global t
  :init-value nil
  :lighter nil
  :keymap compile-target-mode-map

  (progn
    (message "compile-target-mode autoload: %s" a9flow-compiler-mode)
    ))

