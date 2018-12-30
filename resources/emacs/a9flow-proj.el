;; This is simple addon for a9flow-mode,
;; that allow use project file in flow-mode.
;; author: Evgeniy Turishev evgeniy.turishev@area9.dk
;;
;; Project file is normal elisp-file, for example:
;;
;; (a9flow-proj-add :name "proj-1"
;; 		 :prog "flowcpp"
;; 		 :main-file "mkbootcamp.flow"
;; 		 :options "--media-path ~/area9/material/ -I ~/area9/material -I ~/area9/flow -I ~/area9/mkbootcamp"
;; 		 :app-options "dev=1 url='http://127.0.0.1:80/'")
;;
;; (a9flow-proj-add :name "proj-2"
;; 		 :prog "flow"
;; 		 :main-file "main.flow")
;;
;; The 'app-options' will be added to the command line after '--'.
;;
;; Many projects in one file are alowed,
;; 'name', 'prog', 'main-file' args are required, other arguments are optional.
;;
;; For load project:
;; M-x load-file

(require 'cl)
(require 'a9flow-mode)

(defvar a9flow-proj-list () "a9flow projects list")

(cl-defun a9flow-proj-add (&key name prog main-file options app-options)
  "Add project (or replace) to project list"
  (if (and (stringp name) (stringp prog) (stringp main-file))
      (setq a9flow-proj-list
	    (cons (list 'name name 'prog prog 'main-file main-file 'options options 'app-options app-options)
		  (cl-delete name a9flow-proj-list :test 'equal :key (lambda (proj) (plist-get proj 'name)))))
  (massage "load project error: name:'%s'" name)))

(defun a9flow-proj-find (name)
  (cl-find name a9flow-proj-list :test 'equal :key (lambda (proj) (plist-get proj 'name))))

(defun a9flow-proj-compile (project-name)
  "Compile project project-name"
  (interactive	"sProject name: ")
  ;;(message "compile proj:%s" project-name)
  (let ((proj (a9flow-proj-find project-name)))
    (if proj
	(let ((file-name (plist-get proj 'main-file))
	      (a9flow-compiler-path (a9flow-program-path (plist-get proj 'prog)))
	      (opt-1 (plist-get proj 'options))
	      (cwd (file-name-directory (buffer-file-name)))
	      (opt-2 (plist-get proj 'app-options)))
	  (compile
	   (concat
	    a9flow-compiler-path
	    (when cwd (concat " -I " cwd))
	    (when (and opt-1 (not (string= opt-1 ""))) (concat " " opt-1))
	    " " file-name
	    (when (and opt-2 (not (string= opt-2 ""))) (concat " -- " opt-2)))))
      (message "project '%s' not found" project-name))))

(defun a9flow-proj-compile-default ()
  "Compile the last-added project"
  (interactive)
  (a9flow-proj-compile (plist-get (car a9flow-proj-list) 'name)))


(provide 'a9flow-proj)
