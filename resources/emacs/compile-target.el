;; compile-target.el --- Simple project management minor mode  -*- lexical-binding:t -*-

;; Copyright (C) 2024 Evgeniy Turishev

;; Author: Evgeniy Turishev evgeniy.turishev@area9.dk

;; This file is not part of GNU Emacs.

;;; License:

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;;; Commentary:

;; A simple project management minor mode, which serves the following purposes:
;; 1) select a project root directory
;; 2) manage a command list with short names that will be executed in emacs compilation mode
;; 3) make any changes to the emacs environment when opening a project
;;
;; A 'project-file' is ordinary elisp file with zero, one or more invocations of
;;
;;   (compile-target-add NAME COMMAND-STRING)
;;
;; It allow you also to add any elisp stuff to adjust your project.

;; to open project:
;;   M-x compile-target-open-project
;;
;; After that, all commands will run in a project directory (where a project file is placed).
;;
;; You can set compile-target-after-open-project hook to catch select project event, to get a project directory and so on:
;; (setq compile-target-after-open-project (lambda () ...))
;;
;; Use ivy or ido to use it with more comfort.
;;   M-x compile-target-compile-ivy
;;   M-x compile-target-compile-ido
;;
;; compile last used target or first in targets list (if not any selected yet)
;;   M-x compile-target-compile-default
;;
;; set project directory explicitly
;;   M-x compile-target-set-dir

(require 'cl-lib)
(require 'compile)


(defvar compile-target-project-file nil
  "compile-target current project file name")

(defvar compile-target-project-directory "./"
  "compile-target project directory, default value is './'")

(defvar compile-target-target-list ()
  "compile-target targets list")

(defvar compile-target-default-target nil
  "compile-target default target")

(defvar compile-target-after-open-project nil
  "a hook-like function to check project state after project loaded")


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
  (setq compile-target-project-directory (file-name-directory project-file-name))
  (message "compile-target project:%s" project-file-name)
  (message "compile-target directory:%s" compile-target-project-directory)
  (load-file project-file-name)
  (when (functionp compile-target-after-open-project)
    (funcall compile-target-after-open-project)))


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
	(let ((compile-cmd (plist-get proj 'compile-cmd))
	      (work-dir (plist-get proj 'work-dir))
	      (curr-dir default-directory))

	  (setq compile-target-default-target target-name)
	  (cd compile-target-project-directory)
	  (compile compile-cmd)
	  (cd curr-dir))
      (message "Target '%s' not found" target-name))))


(defun compile-target-compile-default ()
  "Compile default target"
  (interactive)
  (compile-target-compile compile-target-default-target))


(defun compile-target-set-dir (dir)
  "Set project directory"
  (interactive "DDirectory: ")
  (setq compile-target-project-directory dir))


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
    (message "compile-target-mode autoload: %s" compile-target-mode)))

(provide 'compile-target)
;;; compile-target.el ends here
