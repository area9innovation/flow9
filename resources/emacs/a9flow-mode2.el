;;  a9flow-mode2.el
;;
;; Major mode to edit flow files in Emacs with project support
;; with fixes for new flowc compiler
;; Author: Evgeniy Turishev evgeniy.turishev@area9.dk
;; This module based on original a9flow-mode Nikolay Sokolov <Nikolay.Sokolov@area9.dk>

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; a9flow-mode.el --- Major mode to edit flow files in Emacs
;;
;; Version: 0.0.1
;; Keywords: Area9 Flow major mode
;; Author: Nikolay Sokolov <Nikolay.Sokolov@area9.dk>
;;
;; This file is not part of GNU Emacs.
;;
;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;;; Simple project support ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Creating project file
;; it is a ordinary elisp-file, for example:
;;
;; (a9flow-add-target "learner-js"  "flowc1 learner/learner.flow js=~/area9/lyceum/rhapsode/www2/learner.js")
;; (a9flow-add-target "educator" :compile-cmd "flowcpp --no-jit educator/educator.flow -- devtrace=1 dev=1")
;; 		 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Load project:
;; M-x a9flow-open-project
;;
;; Compile project:
;; M-x a9flow-compile-project
;; or more convenient with ido:
;; M-x a9flow-compile-project-ido
;;
;; You can set default target:
;; M-x a9flow-set-default-target
;;  or more convenient with ido:
;; M-x a9flow-set-default-target-ido
;; and then compile it:
;; M-x a9flow-compile-default-target
;;
;; find function definition or import file:
;; M-x a9flow-goto-definition
;; and
;; M-x a9flow-go-back
;;
;; go to function body in this file:
;; M-x a9flow-goto-function-body
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; You can add to your .emacs something like:
;;
;; (require 'a9flow-mode2)
;;
;; (setq auto-mode-alist
;;      (append '(("\\.flow$" . a9flow-mode)) auto-mode-alist))
;;
;; (add-hook 'a9flow-mode-hook
;; 	  (lambda ()
;; 	    (setq tab-width 4)
;; 	    (local-set-key (kbd "C-c o") 'a9flow-open-project)
;; 	    (local-set-key (kbd "C-c p") 'a9flow-compile-project-ido)
;; 	    (local-set-key (kbd "C-c d") 'a9flow-set-default-target)
;; 	    (local-set-key (kbd "C-c c") 'a9flow-compile-default-target)
;; 	    (local-set-key (kbd "M-.")   'a9flow-goto-definition)
;; 	    (local-set-key (kbd "M-,")   'a9flow-go-back)
;; 	    (local-set-key (kbd "M-/")   'a9flow-goto-function-body)
;; 	    (local-set-key (kbd "C-.")   'a9flow-history-point)
;; 	    )
;; 	  )
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(require 'cl)

;;;; Syntax ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(require 'generic-x)

(setq a9flow-compat nil) ;; Compatibility mode

(defvar a9flow-mode-syntax-table
  (let ((a9flow-mode-syntax-table (make-syntax-table)))
    (modify-syntax-entry ?/ ". 124b" a9flow-mode-syntax-table)
    (modify-syntax-entry ?* ". 23" a9flow-mode-syntax-table)
    (modify-syntax-entry ?\n "> b" a9flow-mode-syntax-table)
    (modify-syntax-entry ?< "." a9flow-mode-syntax-table)
    (modify-syntax-entry ?> "." a9flow-mode-syntax-table)
    a9flow-mode-syntax-table)
  "`define-generic-defun' takes COMMENT-LIST, but its support for
ending comments with the lint terminator seems not to work,
so here we are setting up our own syntax table.")

(defun line-matchesp (regexp offset)
  "Return t if line matches regular expression REGEXP.  The
selected line is chosen by applying OFFSET as a numeric
increment or decrement away from the current line number.
This function modifies the match data that `match-beginning',
`match-end' and `match-data' access; save and restore the match
data if you want to preserve them."
  (interactive)
  (save-excursion
    (forward-line offset)
    (beginning-of-line)
    (looking-at regexp)))

(defun previous-line-matchesp (regexp)
  "Return t if previous line matches regular expression REGEXP.
This function modifies the match data that `match-beginning',
`match-end' and `match-data' access; save and restore the match
data if you want to preserve them."
  (interactive)
  (line-matchesp regexp -1))

(defun current-line-matchesp (regexp)
  "Return t if current line matches regular expression REGEXP.
This function modifies the match data that 'match-beginning',
'match-end' and 'match-data' access; save and restore the match
data if you want to preserve them."
  (interactive)
  (line-matchesp regexp 0))

(defun a9flow-indent-line ()
  (interactive)
  "Establish a set of conditional cases for the types of lines that
point currently is on, and the associated indentation rules."
  (indent-line-to
   (cond
    ((and
      (previous-line-matchesp "^[ \t]*\\*")
      (current-line-matchesp "^[ \t]*\\*"))
     (save-excursion
       (forward-line -1)
       (current-indentation)))
    ((and
      (previous-line-matchesp "^[ \t]*/\\*")
      (current-line-matchesp "^[ \t]*\\*"))
     (save-excursion
       (forward-line -1)
       (+ (current-indentation) 1)))
    ((and
      (previous-line-matchesp "^[ \t]*\\.")
      (current-line-matchesp "^[ \t]**\\."))
     (save-excursion
       (forward-line -1)
       (current-indentation)))
    ((and
      (not (previous-line-matchesp "^[ \t]*\\."))
      (current-line-matchesp "^[ \t]*\\."))
     (save-excursion
       (forward-line -1)
;       (+ (current-indentation) default-tab-width)))
       (+ (current-indentation) tab-width)))
    ((current-line-matchesp "^[ \t]*}")                            ;; } closing if block inside a statement (06, 07, 08, 09)
     (save-excursion
       (beginning-of-line)
       (backward-up-list)
       (cond
        ((current-line-matchesp "^[ \t}]*else[ \t]+if.*\)[ \t]*{[ \t]*$")
         (current-indentation))
        ((current-line-matchesp "^.*[a-z]+.*if.*\)[ \t]*{[ \t]*$")
         (+ (current-indentation) tab-width))
        (t
         (current-indentation)))
       ))
    ((current-line-matchesp "^[ \t]*[]}\)]")
     (save-excursion
       (beginning-of-line)
       (backward-up-list)
       (current-indentation)))
    ((previous-line-matchesp "^.*\\(\\\\\\).*\\(->\\)[ \t]*$")
     (save-excursion
       (beginning-of-line)
       (previous-line)
       (+ (current-indentation) tab-width)))
    ;; else after a close bracket (06, 07, 08, 09)
    ((and
      (current-line-matchesp "^[ \t]*else.*$")
      (previous-line-matchesp "^.*}[ \t]*$")
      (save-excursion
       (beginning-of-line)
       (previous-line)
       (current-indentation)))
     )
    ;; else after one-line else if (04)
    ((and
      (or
       (current-line-matchesp "^[ \t]*else.*$")
       (current-line-matchesp "^[ \t]*else[ \t]+if.*\)[ \t]*$"))
      (previous-line-matchesp "^[ \t]*else[ \t]+if.*\).*$")
      )
     (save-excursion
       (beginning-of-line)
       (previous-line)
       (current-indentation)))
    ;; else after one-line if in a statement (03)
    ((and
      (or
       (current-line-matchesp "^[ \t]*else.*$")
       (current-line-matchesp "^[ \t]*else[ \t]+if.*\)[ \t]*$"))
      (previous-line-matchesp "^.*[a-z]+.*[ \t]if.*\).*$")
      )
     (save-excursion
       (beginning-of-line)
       (previous-line)
       (+ (current-indentation) tab-width)))
    ;; else after one-line if (04)
    ((and
      (or
       (current-line-matchesp "^[ \t]*else.*$")
       (current-line-matchesp "^[ \t]*else[ \t]+if.*\)[ \t]*$"))
      (previous-line-matchesp "^.*[ \t]if.*\).*$")
      )
     (save-excursion
       (beginning-of-line)
       (previous-line)
       (current-indentation)))
    ;; simple else (01)
    ((or
      (current-line-matchesp "^[ \t]*else[ \t]*$")
      (current-line-matchesp "^[ \t]*else[ \t]*if.*\)[ \t]*$"))
     (save-excursion
       (beginning-of-line)
       (previous-line)
       (- (current-indentation) tab-width)))
    ;; else after close bracket on the same line (12)
    ((previous-line-matchesp "^[ \t}]*else[ \t]*$")
     (save-excursion
       (beginning-of-line)
       (previous-line)
       (+ (current-indentation) tab-width)))
    ;; simple if (02, 10)
    ((previous-line-matchesp "^[ \t]*[ \t]if.*\)[ \t]*$")
     (save-excursion
       (beginning-of-line)
       (previous-line)
       (+ (current-indentation) tab-width)))
    ;; if inside a statement (01)
    ((previous-line-matchesp "^.*[ \t]if.*\)[ \t]*$")
      (save-excursion
       (beginning-of-line)
       (previous-line)
       (+ (current-indentation) (* tab-width 2))))
    ;; else if  with { at the end (09)
    ((previous-line-matchesp "^[ \t}]*else[ \t]+if.*\)[ \t]*{[ \t]*$")
      (save-excursion
       (beginning-of-line)
       (previous-line)
       (+ (current-indentation) tab-width)))
    ;; if inside a statement with { at the end (06, 07, 08, 09)
    ((previous-line-matchesp "^.*[a-z].*if.*\)[ \t]*{[ \t]*$")
      (save-excursion
       (beginning-of-line)
       (previous-line)
       (+ (current-indentation) (* tab-width 2))))
    ((previous-line-matchesp "^.*=[ \t]*$")
     (save-excursion
       (beginning-of-line)
       (backward-up-list)
       (+ (current-indentation) (* tab-width 2))))
    ((current-line-matchesp "^[ \t]*|>")
     (save-excursion
       (beginning-of-line)
       (previous-line)
       (current-indentation)))
    (t
     (save-excursion
       (condition-case nil
           (progn
             (beginning-of-line)
             (backward-up-list)
             (if (current-line-matchesp "^.*[a-z]+.*if.*\)[ \t]*{[ \t]*$")
                 (+ (current-indentation) (* tab-width 2))
                 (+ (current-indentation) tab-width)))
         (error 0)))))))

(defconst a9flow-keywords '(
  "import"
  "export"
  "if"
  "else"
  "ref"
  "true"
  "false"
))

(defconst a9flow-builtins '(
  "println"
  "printCallstack"
  "make"
  "const"
  "next"
  "getValue"
  "select"
  "select2"
  "select3"
  "subscribe"
  "subscribe2"
  "connect"
  "math"
  "target"
  "i2s"
  "i2d"
  "d2s"
  "d2i"
  "round"
  "length"
  "assert"
  "subrange"
  "idfn"
  "max"
  "min"
  "render"
))

(defconst a9flow-types '(
  "int"
  "string"
  "bool"
  "double"
  "flow"
  "void"
  "float"
))

(defconst type_regex "\\[?\\s-*\\([a-zA-Z]+\\)\\s-*\\]?")

(defvar hexcolour-keywords
  '(("0x\\([abcdefABCDEF[:digit:]]\\{6\\}\\)"
     (0 (put-text-property (match-beginning 0)
                           (match-end 0)
                           'face (list :background
                                       (progn
                                         (message (concat "#" (match-string-no-properties 1)))
                                         (concat "#" (match-string-no-properties 1)))))))))


(defvar a9flow-status-compiling nil)
(defvar a9flow-status-error-count 0)
(defvar a9flow-status-last-build-time nil)


;; Set up the actual generic mode
(define-generic-mode 'a9flow-mode
  nil ;; comment-list
  ;;a9flow-keywords ;; keyword-list
  '()
  ;; font-lock-list
  `(("\\(\\s(\\|\\s-+\\|\\<\\)\\(\\<[A-Z]\\(\\sw\\|\\s_\\)+\\>\\)" (2 'font-lock-type-face))
    ("\\b[0-9]+\\b" . font-lock-constant-face)
    ("|>" . font-lock-builtin-face)

;; Type highlighting
;;    ("^\\+" (,(concat ":\\s-*\(\\(\\s-*,?\\s-*[a-zA-Z]+\\(\\s-*:\\s-*" type_regex "\\s-*\\)?\\)*\).*->\\s-*" type_regex "\\s-*{") nil nil (3 'font-lock-type-face)))
;;    (,(concat "->\\s-*" type_regex "\\s-*[{;]") 1 'font-lock-type-face)

    (,(regexp-opt a9flow-keywords 'words) . 'font-lock-keyword-face)
    (,(regexp-opt a9flow-builtins 'words) . 'font-lock-builtin-face)
    (,(regexp-opt a9flow-types 'words) . 'font-lock-type-face)

    ;; fontify x in local declarations like:   x : Foo = ...
    ("^\\s-*\\(\\<\\(\\sw\\|\\s_\\)+\\>\\) *\\(:[^=\n]+\\)?=" (1 'font-lock-variable-name-face))

;; Lambdas
    ("\\(\\\\\\).*?\\(->\\)"
     (1 (prog1 ()
          (when (not a9flow-compat)
            (compose-region (match-beginning 1) (match-end 1) ?λ))
          (put-text-property (match-beginning 1) (match-end 1) 'font-lock-face 'font-lock-builtin-face)))
     (2 (prog1 ()
          (if (not a9flow-compat)
              (progn
                (compose-region (match-beginning 2) (match-end 2) ?→)
                (put-text-property (match-beginning 2) (- (match-end 2) 1) 'font-lock-face 'font-lock-builtin-face))
              (put-text-property (match-beginning 2) (match-end 2) 'font-lock-face 'font-lock-builtin-face)))))
    (").*?\\(->\\)"
     (1 (prog1 ()
          (when (not a9flow-compat)
            (compose-region (match-beginning 1) (match-end 1) ?→))
          (put-text-property (match-beginning 1) (match-end 1) 'font-lock-face 'font-lock-builtin-face))))
    ("0x\\([abcdefABCDEF[:digit:]]\\{6\\}\\)"
     (0 (put-text-property (match-beginning 0)
                            (match-end 0)
                            'face (list :background
                                        (progn
                                          ;; (message (concat "#" (match-string-no-properties 1)))
                                          (concat "#" (match-string-no-properties 1))))))))

  ;; auto-mode-list
  '()
  ;; function-list
  '((lambda ()
      (set-syntax-table a9flow-mode-syntax-table)
      (setq comment-start "//")
      (setq comment-end "")
      (setq parse-sexp-ignore-comments t)
      (set (make-local-variable 'indent-line-function) 'a9flow-indent-line)
      (setq mode-line-format (append mode-line-format (list '(:eval 
         (if a9flow-status-compiling
             (concat "Status: Compiling " a9flow-status-compiling "...")
             (if (eq a9flow-status-error-count 0)
                 "Status: Ok"
                 (concat "Status: Compiling errors: " (number-to-string a9flow-status-error-count)))))
                                                            " | "
                                                            '(:eval (if a9flow-status-last-build-time (format-time-string "Last build: %Y/%m/%d %H:%M:%S" a9flow-status-last-build-time) ""))
                                                            ))))))


;;;;;;;;;;;;; PROJECT MANAGEMENT ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defvar a9flow-flow-directory "../../flow9" "a9flow flow directory")
(defvar a9flow-proj-default-directory nil "a9flow default directory")
(defvar a9flow-include-list () "a9flow include directories list")
(defvar a9flow-target-list () "a9flow project targets list")
(defvar a9flow-default-target nil "a9flow default target")

(defvar a9flow-goto-history '())
(defvar a9flow-goto-hash '())

(cl-defun a9flow-add-target (name compile-cmd)
  "Add project (or replace) to project list"
  (if (stringp name)
      (progn
	(setq a9flow-default-target name) 
	(setq a9flow-target-list
	      (cons (list 'name name 'compile-cmd compile-cmd)
	      (cl-delete name a9flow-target-list :test 'equal :key (lambda (proj) (plist-get proj 'name))))))
    (message "load project error: name:'%s'" name)))



(defun a9flow-proj-find (target-name)
  (cl-find target-name a9flow-target-list :test 'equal :key (lambda (proj) (plist-get proj 'name))))

(defun a9flow-open-project (project-file-name)
  "Load project file"
  (interactive	"fProject file: ")
  (let* ((proj-dir (file-name-directory project-file-name))
	(dir (if proj-dir proj-dir default-directory)))
    (message "a9flow project:%s" project-file-name)
    (setq a9flow-proj-default-directory nil)
    (setq a9flow-include-list nil)
    (load-file project-file-name)
    (when (not a9flow-proj-default-directory) (setq a9flow-proj-default-directory dir))
    (a9flow-load-flow-config) ;; after project's load and set a9flow-proj-default-directory    
    (message "a9flow default dir:%s" a9flow-proj-default-directory)
    ;;(message "a9flow include list:\n%s" a9flow-include-list)
    ))  

(defun a9flow-compile-project-ido ()
  (interactive)
  (if (fboundp 'ido-completing-read)
      (progn
        (setq target-name (ido-completing-read "Compile target: " (mapcar 'cadr a9flow-target-list)))
        (a9flow-compile-project target-name))
    (message "ido not found")))

(defun a9flow-compile-project (target-name)
  "Compile project's target"
  (interactive	"sTarget name: ")
  ;;(setq compilation-filter-hook 'a9flow-compile-filter-hk)
  (let ((proj (a9flow-proj-find target-name)))
    (if proj
	(let ((compile-cmd (plist-get proj 'compile-cmd))
	      (work-dir (plist-get proj 'work-dir)))
	    (cd a9flow-proj-default-directory)
	    (compile compile-cmd))
      (message "Target '%s' not found" target-name))))

(defun a9flow-compile-default-target ()
  "Compile the default project"
  (interactive)
  (a9flow-compile-project a9flow-default-target))

(defun a9flow-set-default-target-ido ()
  (interactive)
  (if (fboundp 'ido-completing-read)
      (progn
        (setq target-name (ido-completing-read "Default target: " (mapcar 'cadr a9flow-target-list)))
        (a9flow-set-default-target target-name))
    (message "ido not found")))

(defun a9flow-set-default-target (target-name)
  "Set default target"
  (interactive "sTarget name: ")
  (setq a9flow-default-target target-name))


(defun a9flow-find-file-in-include-paths (fname)
  (let ((dir (seq-find (lambda (dir) (file-exists-p (concat dir "/" fname)))  a9flow-include-list)))
    (if dir (concat dir "/" fname) nil)))


(defun a9flow-load-flow-config ()
  (interactive)
  (cd a9flow-proj-default-directory)
  (with-temp-buffer
    (insert-file-contents "flow.config")
    (let ((include (when (string-match "include=\\(.*\\)" (buffer-string))
	   	     (match-string 1 (buffer-string)))))
      (setq a9flow-include-list (append a9flow-include-list (split-string include ",")))
      )))

;;;;;;;;;; GOTO PROCEDURES ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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

(defun a9flow-goto-definition ()
  (interactive)
  (setq cv (buffer-substring-no-properties (line-beginning-position) (line-end-position)))
  (if (string-match "import[ \\t]+\\(.*\\);" cv)
      (a9flow-goto-import)
      (a9flow-goto-function-definition)))

(defun a9flow-goto-import ()
  (interactive)
  (setq current-position `(,(buffer-name) ,(point)))
  (push current-position a9flow-goto-history)
  (let* ((proj (a9flow-proj-find a9flow-default-target))
	 (cv (buffer-substring-no-properties (line-beginning-position) (line-end-position))))
    (string-match "import[ \\t]+\\(.*\\);" cv)
    (let* ((rpath (match-string 1 cv))
	   (fname (concat rpath ".flow"))
	   (tmp-history a9flow-goto-history))
      (message "goto import:%s" rpath)
      (cd a9flow-proj-default-directory)     
      (if (file-readable-p fname)
	  (find-file fname)
	(let ((lib-path (concat a9flow-flow-directory "/lib/" fname)))
	      (message "lib:%s" lib-path)
	      (if (file-readable-p lib-path)
		  (find-file lib-path)
		(let ((f (a9flow-find-file-in-include-paths fname)))
		  (if f (find-file f) (message "file '%s' is not readable or not exists" fname))))))
	  (setq a9flow-goto-history tmp-history))))

(defun a9flow-goto-compiled-definition(word initial-buffer initial-point)
  (setq a9flow-compiler-path "flowc1")
  (cd a9flow-proj-default-directory)
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

(defun a9flow-goto-function-body ()
  (interactive)
  (setq current-position `(,(buffer-name) ,(point)))
  (setq cv (buffer-substring-no-properties (line-beginning-position) (line-end-position)))
  (string-match "^[ \t]*\\([a-zA-Z0-9-_]+\\)[ ]*:?[ ]*\(" cv)
  (setq name (match-string 1 cv))
  (setq res (re-search-forward (concat "^[ \t]*" name "(.*)[ \t]*\\(->[ \t]*[a-zA-Z0-9_-]+[ \t]*\\)?{$") nil t 1))
;;  (message (concat "^[ \t]*" name "(.*)[ \t]*{$"))
  (if res
      (progn
        (push current-position a9flow-goto-history)
        (beginning-of-line))
      (message (concat "Error: " name " function body not found."))))

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


;; (defun a9flow-compile-filter-hk ()
;;   (let ((str (buffer-substring compilation-filter-start (point-max)))
;; 	err-msg)
;;     (when (string-match  "\"\\(neko .+\\)\"" str)
;;       (setq err-msg (match-string 1 str))
;;       (when err-msg (insert (replace-regexp-in-string "\\\\n" "\n"  err-msg))))))

;; (defun a9flow-set-compile-filter ()
;;   (setq compilation-filter-hook 'a9flow-compile-filter-hk))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;




(provide 'a9flow-mode2)
