;;; a9flow-mode.el --- Major mode to edit flow files in Emacs

;; Version: 0.0.1
;; Keywords: Area9 Flow major mode
;; Author: Nikolay Sokolov <Nikolay.Sokolov@area9.dk>

;; This file is not part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program; if not, write to the Free Software
;; Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

;;; Commentary

;; Provides syntax highlighting, indentation support, compilation,
;; project navigation, and a few cute commands.

;;; Compilation
;;
;; The function `a9flow-compile' compiles given file
;;   (path should be relative to the specified root folder)
;; The function `a9flow-compile-project' compiles one of
;;   the projects you configured before
;;   For the information about project configuration see "Configuration" section
;; The function `a9flow-compile-project-ido' compiles one of
;;   the projects you configured before (with ido extension help if it's present)
;; During compilation process you can see its status in the mode-line
;; It there are some errors after compilation, output buffer will be opened.

;;; Running
;;
;; There are also functions for running projects.
;; The function a9flow-run-buffer runs current buffer with flowcpp
;; The functions a9flow-run-project and a9flow-run-project-ido run preconfigured project

;;; Navigation
;;
;;  You can use `M-.' to navigate to a function definition or an imported file
;;  `M-,' returns you back
;;  `M-;' takes you from function definition to it's body

;;; Stack
;;
;;  `a9flow-stack-yank' command will create a new buffer with flow-stack specific mode
;; Some shortcuts are present:
;;   S - show the line in the code (without window switch)
;;   G - goto the line

;;; Misc
;;
;; Also, you can yank a flow object string with a command `a9flow-object-yank'
;; it will be slightly formatted

;;; Configuration
;;
;; See a9flow-configuration-example.el

(require 'generic-x)

(setq a9flow-compat nil) ;; Compatibility mode

;; reasonable defaults for Mac & Linux. on Windows, override these
;; in your init file
(defcustom a9flow-basedir "~/flow/"
  "area9 code base directory"
  :safe #'stringp)
(defcustom a9flow-include-dirs '("~/flow/" "~/flow/lib/")
  "include directories for flow compiler")
(defcustom a9flow-compiler-basedir "~/flow/"
  "path to the flow compiler (svn root)")

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
    ;; else if without { at the end (09)
    ((previous-line-matchesp "^[ \t}]*else[ \t]+if.*\)[ \t]*$")
      (save-excursion
       (beginning-of-line)
       (previous-line)
       (+ (current-indentation) tab-width))
      )
    ;; if inside a statement (01)
    ((previous-line-matchesp "^.*[ \t]if.*\)[ \t]*$")
      (save-excursion
       (beginning-of-line)
       (previous-line)
       (+ (current-indentation) (* tab-width 2))))
    ;; else if with { at the end (09)
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
             (cond
              ((current-line-matchesp "^[\t }]*else[\t ]*if.*\)[ \t]*{[ \t]*$")
               (+ (current-indentation) tab-width)
               )
              ((current-line-matchesp "^.*[a-z]+.*if.*\)[ \t]*{[ \t]*$")
               (+ (current-indentation) (* tab-width 2))
               )
              (t
               (+ (current-indentation) tab-width)
               )
             ))
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

(defvar a9flow-goto-history '())
;; (make-variable-buffer-local 'a9flow-goto-history)
(defvar a9flow-status-compiling nil)
;; (make-variable-buffer-local 'a9flow-status-compiling)
(defvar a9flow-status-error-count 0)
(defvar a9flow-status-last-build-time nil)
(defvar a9flow-goto-hash '())

(defvar a9flow-main-project-file nil)

;; Try to guess the root of the current source tree.  Returns the
;; current buffer's directory or some ancestor of it.
;;
;; The following code won't work in every conceivable case, because we don't
;; know what include paths the user might be planning to pass to the compiler
;; with -I.  So we try a series of strategies.

(defun guess-root ()
  ;; maybe there's a directory somewhere above us called "flow".
  ;; if so return that
  (or (locate-dominating-file
       default-directory
       (lambda (dir)
         (string= "flow" (file-name-nondirectory (directory-file-name dir)))))
      ;; maybe there's a directory somewhere above us with a *.sublime-project file.
      ;; if so return that directory.
      (locate-dominating-file
       default-directory
       (lambda (dir) (directory-files dir nil ".sublime-project$")))
      ;; give up, return current directory
      default-directory))

;; - M-.
;;   - If word exists in the cache
;;     ? - Switch (or open) specified file
;;       - Go to specified line
;;       - Lines content is equal to saved
;;         ? Success
;;         : - Trying to find saved content
;;           ? - If some lines found, go to the first one
;;           : - Searching through compilation
;;     : - Searching through compilation

;; - Searching through compilation
;; - Successfully compiled?
;;   ? - Go to retrieved file, line num
;;     - Adding new data to the cache
;;   : - Report error
;;     - Go to initial position

(defun a9flow-goto-function-definition ()
  (interactive)
  (let ((default-directory (guess-root)))
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
        (a9flow-goto-compiled-definition cw current-buffer current-point))))

(defun a9flow-program-path (name)
  (concat a9flow-compiler-basedir
          (if (eq system-type 'windows-nt)
            (concat "bin\\" name ".bat")
            (concat "bin/" name))))

(defun a9flow-goto-compiled-definition (word initial-buffer initial-point)
  (if (not a9flow-main-project-file)
      (a9flow-change-main-file ()))
  (setq a9flow-compiler-path (a9flow-program-path "flow"))
  (setq command-to-execute (concat a9flow-compiler-path " --root . " (mapconcat (lambda (el) (concat "-I " el)) a9flow-include-dirs " ") " --find-definition " word " " (file-relative-name (buffer-file-name))))
  (message command-to-execute)
  (setq res (shell-command-to-string command-to-execute))
  (setq matched-result (string-match "\(\\([a-zA-Z0-9\-_/:\\\\]+\\.flow\\):\\([0-9]+\\)@" res))
  (if matched-result
      (progn
        (setq rel-path (match-string 1 res))
        (setq line-num (string-to-number (match-string 2 res)))
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

(defun a9flow-goto-import ()
  (interactive)
  (setq current-position `(,(buffer-name) ,(point)))
  (push current-position a9flow-goto-history)
  (setq cv (buffer-substring-no-properties (line-beginning-position) (line-end-position)))
  (string-match "import[ \\t]+\\(.*\\);" cv)
  (setq ilib (match-string 1 cv))
  (setq rel-path ilib)
  (setq tmp-history a9flow-goto-history)
  (find-file (a9flow-find-filename rel-path))
  (setq a9flow-goto-history tmp-history))

(defun a9flow-find-filename (rel-path)
  (defun a9flow-find-path-inner (left-paths)
    (if (= (length left-paths) 0)
        ""
        (setq filename (concat (car left-paths) "/" rel-path ".flow"))
        (if (file-exists-p filename)
            filename
            (a9flow-find-path-inner (cdr left-paths)))))
  (a9flow-find-path-inner a9flow-include-dirs))

(defun a9flow-goto-definition ()
  (interactive)
  (setq cv (buffer-substring-no-properties (line-beginning-position) (line-end-position)))
  (if (string-match "import[ \\t]+\\(.*\\);" cv)
      (a9flow-goto-import)
      (a9flow-goto-function-definition)))

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

;; Make filename buffer-local
(defun a9flow-change-main-file (filename)
  (interactive "fMain project file path: ")
  (setq a9flow-main-project-file filename))

(defun a9flow-stack-yank ()
  (interactive)
  (switch-to-buffer-other-window "*FlowStack*")
  (setq buffer-read-only nil)
  (erase-buffer)
  (yank)
  (a9flow-stack-format)
  (setq buffer-read-only 1)
  (a9flow-stack-mode))

(defun a9flow-object-yank ()
  (interactive)
  (switch-to-buffer-other-window "*FlowObject*")
  (setq buffer-read-only nil)
  (erase-buffer)
  (yank)
  (goto-char 1)
  (replace-regexp "[(]\\([^)]\\)" "(\n\\1")
  (goto-char 1)
  (replace-regexp "," ",\n")
  (goto-char 1)
  (replace-regexp "[[]\\([^)]\\)" "[\n\\1")
  (js-mode)
  (whitespace-mode)
  (replace-tabs-hook)
  (setq tab-width 2)
  (mark-whole-buffer)
  (indent-region (point-min) (point-max))
;;  (setq buffer-read-only 1)
)

(defun a9flow-compilation-finished (msg)
  (cond
   ((string-match "^.*\\s.flow:" msg)
    (progn
      (pop-to-buffer "*FlowOutput*")
      (previous-multiframe-window)
      nil))
   ((string-match "^Compilation finished" msg)
    (progn
      (let ((outputWindow (get-buffer-window "*FlowOutput*")))
        (when outputWindow
          (progn
            (select-window outputWindow)
            ;; (a9flow-stack-mode)
            (compilation-mode)
            (save-excursion
              (progn
                (beginning-of-buffer)
                (setq a9flow-status-error-count (count-matches "^[[:alnum:]_/.+-]+:[0-9]+:"))))
            ;; (setq buffer-read-only 1)
            (previous-multiframe-window)
          )))
      (setq a9flow-status-compiling nil)
      (setq a9flow-status-last-build-time (current-time))
      (message "Compilation finished"))
    )
   ))

(add-hook 'comint-output-filter-functions 'a9flow-compilation-finished)

(defun a9flow-shell-command-on-buffer-other (command)
  (when (not a9flow-status-compiling)
    (setq a9flow-status-compiling ""))
  (let ((default-directory a9flow-basedir))
    (interactive "sShell command on buffer: ")
    (setq ismultiwin (not (eq (next-window) (selected-window))))
    (setq outputWindow (get-buffer-window "*FlowOutput*"))
    ;;(switch-to-buffer-other-window "*FlowOutput*")
    (pop-to-buffer "*FlowOutput*")
    (setq buffer-read-only nil)
    (erase-buffer)
    (shell "*FlowOutput*")
    (shell-mode)
    (end-of-buffer)
    (insert command)
    (comint-send-input)
    ;;(previous-multiframe-window)
    (message "Compilation started")
    (if ismultiwin
        (progn
          (when (not outputWindow)
            (switch-to-buffer (other-buffer)))
          (previous-multiframe-window)
        )
        (delete-window))
    ))

(defun then-echo-compilation-finished ()
  (concat
   (if (eq system-type 'windows-nt) " &" " ;")
   " echo Compilation finished"
   ))

(defun a9flow-compile (input-file arguments)
  (interactive "sInput file: \nsArguments: ")
  (if project-info
      (progn
        (setq file-name (buffer-file-name))
        (setq a9flow-compiler-path (a9flow-program-path "flow"))
        (a9flow-shell-command-on-buffer-other (concat
                                               a9flow-compiler-path
                                               " --incremental "
                                               arguments " "
                                               input-file
                                               (then-echo-compilation-finished))))))

(defun a9flow-compile-buffer ()
  (interactive)
  (progn
    (setq file-name (buffer-file-name))
    (setq a9flow-compiler-path (a9flow-program-path "flowcpp"))
    (a9flow-shell-command-on-buffer-other (concat
                                           a9flow-compiler-path
                                           " " file-name
                                           (then-echo-compilation-finished)))))

(defun a9flow-lint-buffer ()
  (interactive)
  (progn
    (setq file-name (buffer-file-name))
    (setq a9flow-compiler-path (a9flow-program-path "lint"))
    (a9flow-shell-command-on-buffer-other (concat
                                           a9flow-compiler-path
                                           " " file-name
                                           (then-echo-compilation-finished)))))

(defvar a9flow-projects nil) ;;Format: (name input-file param-list)
(defun a9flow-compile-project (project-name)
  (interactive "sProject name: ")
  (let ((default-directory a9flow-basedir)
        (project-info (assoc project-name a9flow-projects)))
    (if project-info
        (progn
          (setq file-name (buffer-file-name))
          (setq a9flow-compiler-path (a9flow-program-path "flow"))
          (setq a9flow-status-compiling project-name)
          (setq a9flow-status-error-count 0)
          (a9flow-shell-command-on-buffer-other (concat
                                                 a9flow-compiler-path
                                                 " --incremental "
                                                 (mapconcat (lambda (a) a) (nth 2 project-info) " ") " "
                                                 (nth 1 project-info)
                                                 (then-echo-compilation-finished)))))))
(defun a9flow-compile-project-ido ()
  (interactive)
  (if (fboundp 'ido-completing-read)
      (progn
        (setq project-name (ido-completing-read "Project name: " (mapcar 'car a9flow-projects)))
        (a9flow-compile-project project-name))
    (message "ido not found")))

(defun a9flow-run-buffer ()
  (interactive)
  (let ((default-directory a9flow-basedir))
    (progn
      (setq file-name (buffer-file-name))
      (setq a9flow-compiler-path (a9flow-program-path "flowcpp"))
      (a9flow-shell-command-on-buffer-other (concat
                                             a9flow-compiler-path
                                             " --debug-mi " file-name)))))

(defun a9flow-run-project (project-name)
  (interactive "sProject name: ")
  (let ((default-directory a9flow-basedir)
        (project-info (assoc project-name a9flow-projects)))
    (if project-info
        (progn
          (setq file-name (buffer-file-name))
          (setq a9flow-compiler-path (a9flow-program-path "flowcpp"))
          (a9flow-shell-command-on-buffer-other (concat
                                                 a9flow-compiler-path
                                                 " "
                                                 (nth 1 project-info)))))))

(defun a9flow-run-project-ido ()
  (interactive)
  (if (fboundp 'ido-completing-read)
      (progn
        (setq project-name (ido-completing-read "Project name: " (mapcar 'car a9flow-projects)))
        (a9flow-run-project project-name))
    (message "ido not found")))

(defun a9flow-find-word (word)
  (interactive "sFind: ")
  (if (eq system-type 'windows-nt)
      (let ((shell-file-name "c:/cygwin/bin/bash.exe")
            (find-program "/usr/bin/find")
            (grep-find-command `("/usr/bin/find . -type f -exec grep -n  {} \";\"" . 30))
            (grep-find-template "/usr/bin/find . <X> -type f <F> -exec grep <C> -n <R> {} /dev/null \";\""))
        (rgrep word "*.flow" a9flow-basedir))
      (rgrep word "*.flow" a9flow-basedir))
)

(defun a9flow-find-usages ()
  (interactive)
  (a9flow-history-point)
  (a9flow-find-word (current-word))
)

(defvar a9flow-mode-hook nil)

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
    (").*?\\(->\\)."
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

(require 'a9flow-stack-mode)
(provide 'a9flow-mode)
