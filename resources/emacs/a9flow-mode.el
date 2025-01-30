;;  a9flow-mode.el
;;
;; Major mode to edit a9flow source files
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
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; add to your .emacs.d/init.el:
;;
;; (require 'a9flow-mode)
;;
;; (setq auto-mode-alist
;;      (append '(("\\.flow$" . a9flow-mode)) auto-mode-alist))
;;
;; (add-hook 'a9flow-mode-hook
;; 	  (lambda ()
;;           ...
;; 	    )
;; 	  )

(provide 'a9flow-mode) ;; the feature name corresponds to the file name

(defvar a9flow-mode-map
  (let ((map (make-sparse-keymap)))
    map)
  "Keymap for `a9flow-mode'.")

;;;; Syntax ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defvar a9flow-mode-syntax-table
  (let ((a9flow-mode-syntax-table (make-syntax-table)))
    (modify-syntax-entry ?/ ". 124b" a9flow-mode-syntax-table)
    (modify-syntax-entry ?* ". 23" a9flow-mode-syntax-table)
    (modify-syntax-entry ?\n "> b" a9flow-mode-syntax-table)
    (modify-syntax-entry ?< "." a9flow-mode-syntax-table)
    (modify-syntax-entry ?> "." a9flow-mode-syntax-table)
    a9flow-mode-syntax-table)
  "`Syntax table used while in A9Flow")

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
  "forbid"
  "export"
  "if"
  "else"
  "ref"
  "true"
  "false"
  "native"
  "cast"
  "switch"
))

(defconst a9flow-builtins '(
  ;;  runtime
  "for"
  "fori"
  "generate"
  "countUntil"
  "countUntilDown"
  "bitNot"
  "bitAnd"
  "bitOr"
  "bitXor"
  "random"
  "apply0"
  "eq"
  "neq"
  "any"
  "all"
  "idfn"
  "nop"
  "nop1"
  "nop2"
  "nop3"
  "nop4"
  "nop5"
  "nop6"
  "executefn"
  "v2a"
  "quit"
  "onQuit"
  "setCurrentDirectory"
  "getCurrentDirectory"
  "getFileContent"
  "setFileContent"
  "setFileContentUTF16"
  "splitBy"
  "max"
  "min"
  "timestamp"
  "string2time"
  "time2string"
  "timeit"
  "timestampToDay"
  "dayToTimestamp"
  "ignore"
  "assert"
  "b2s"
  "s2b"
  "s2i"
  "i2s"
  "d2s"
  "s2d"
  "b2i"
  "i2b"
  "b2d"
  "d2b"
  "setKeyValue"
  "getKeyValue"
  "removeKeyValue"
  "removeAllKeyValues"
  "getKeysList"
  "checkLocalStorageAvailability"
  "disableLocalStorage"
  "getLocalStorageStatus"
  "setSessionKeyValue"
  "getSessionKeyValue"
  "removeSessionKeyValue"

  "println"
  "printCallstack"

  ;; math
  "sum"
  "dsum"
  "max3"
  "min3"
  "maxA"
  "minA"
  "abs"
  "iabs"
  "sign"
  "isign"
  "pow"
  "sin"
  "cos"
  "asin"
  "acos"
  "tan"
  "atan"
  "sqrt"
  "exp"
  "log"
  "floor"
  "ceil"
  "b2sign"
  "dpow"
  "pow2"
  "dpow2"
  "cot"
  "atan2"
  "acot"
  "sinus"
  "cosinus"
  "tangent"
  "cotangent"
  "asinus"
  "acosinus"
  "atangent"
  "acotangent"
  "log10"
  "s2dint"
  "floorEq"
  "roundTo"
  "floorTo"
  "ceilTo"
  "dfloor"
  "dceil"
  "dround"
  "mod"
  "drem"
  "dmod"
  "frac"
  ""
  ""
  "forceRange"
  ;; maybe
  "isNone"
  "isSome"
  "either"
  "eitherMap"
  "eitherFn"
  "eitherFn2"
  "maybeBind"
  "maybeBind2"
  "maybeMap"
  "maybeMap2"
  "maybeApply"
  "onlyOnce"
  "fn2some"

  ;; behavior
  "make"
  "const"
  "next"
  "nextDistinct"
  "updateBehaviour"
  "updateBehaviourDistinct"
  "nextLegacy"
  "isConst"
  "cloneBehaviour"
  "reverseBehaviour"
  "makeWH"

  ;; fusion
  "fselect"
  "fselect2"
  "fselect3"
  "fselect4"
  "fselect5"
  "fselect6"
  "fselect7"
  "fselect8"
  "fselect9"
  "fsubselect"
  "fsubselect2"
  "fsubselect3"
  "makeSubscribe"
  "makeSubscribe2"
  "make2Subscribe"
  "make2Subscribe2"
  "make3Subscribe"
  "make3Subscribe2"
  "make4Subscribe"
  "make4Subscribe2"
  "make5Subscribe"
  "make5Subscribe2"
  "makeSubscribeUns"
  "makeSubscribeUnsTimer"
  "makeSubscribe2Uns"
  "makeSubscribe2UnsTimer"
  "fgetValue"
  "fmax"
  "fmin"
  "fmax3"
  "fmin3"
  "fmaxA"
  "fminA"
  "farray"
  "fconcat"
  "farrayPush"
  "fconcatA"
  "fcontains"
  "fif"
  "feq"
  "fneq"
  "fequal"
  "fnotequal"
  "fnot"
  "fand"
  "fOr"
  "fxor"
  "fabs"
  "fpair"
  "fBidirectionalLink"
  "fwidthheight"
  "fwidth"
  "fheight"
  "fsumi"
  "fsum"
  "fmap"

  
  ""
  "interruptibleTimerUns"
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

  "render"

  ;;ds/array
  "length"
  "concat"
  "concat3"
  "concatA"
  "map"
  "mapi"
  "mapConcat"
  "mapiConcat"
  "mapWithPrevious"
  "fold"
  "foldi"
  "foldr"
  "replace"
  "arrayPush"
  "arrayPushMaybe"
  "arrayRepeat"
  "subrange"
  "tail"
  "tailFrom"
  "take"
  "firstElement"
  "lastElement"
  "elementAt"
  "refArrayPush"
  "refConcat"
  "pushWithLimit"
  "enumFromTo"
  "iter"
  "iteri"
  "iteriUntil"
  "zipWith"
  "zipWith2"
  "zip3With"
  "filter"
  "filtermap"
  "filtermapi"
  "insertArray"
  "insertArray2"
  "arrayResize"
  "arrayAlign"
  "removeFirst"
  "removeAll"
  "removeIndex"
  "removeRange"
  "elemIndex"
  "contains"
  "containsAny"
  "exists"
  "forall"
  "countA"
  "find"
  "findDef"
  "findi"
  "findiDef"
  "findiex"
  "findiex2"
  "lastfindi"
  "lastfindiex"
  "lastfindiex2"
  "findmap"
  "findmapi"
  "findiExtreme"
  "interleave"
  "split"
  "splitByNumber"
  "extract"
  "applyall"
  "applyAllSync"
  "applyAllAsync"
  "applyall1"
  "reverseA"
  "iterArrayDeferred"
  "stylesEqual"
  "existsIndex"
  "sameStartLength"
  "swapIndexes"
  "foldRange"
  "peanoFold"
  "moveElement"
  "array2list"
  "unzip"
  "unzipi"
  "unzipA"
  "unzipA3"
  "unzipA4"

  ;;dynamic
  "isArray"
  "isSameStructType"
  "isSameObj"
  "makeStructValue"
  "extractStructArguments"
  "getDataTagForValue"
  "number2double"
  "flow"
  "flow2b"
  "flow2i"
  "flow2d"
  "flow2s"
  "toString"

  ;;date
  "date2string"
  "date2stringDef"
  "time2stringDef"
  "date2formatString"
  "date2formatStringDef"
  "formatString2date"
  "formatString2dateDef"
  "shortDateFormat"
  "getDateString"
  "getTimeString"
  "getTimeOnlyString"
  "timeStringConvert"

  ;;tree
  "makeTree"
  "makeTree1"
  "lookupTree"
  "lookupTreeDef"
  "lookupTreeSet"
  "setTree"
  "setTreeValues"
  "removeFromTree"
  "popmax"
  "popmin"
  "traversePreOrder"
  "traverseInOrder"
  "traverseRInOrder"
  "findInOrder"
  "findRInOrder"
  "findPreOrder"
  "foldTree"
  "foldRTree"
  "foldTreeBinary"
  "foldMonoidalTree"
  "mapTree"
  "mapTree2"
  "filterTree"
  "isEmptyTree"
  "containsKeyTree"
  "getTreeKeys"
  "getTreeValues"
  "mergeTree"
  "mergeTreeCustom"
  "pairs2tree"
  "tree2pairs"
  "keys2tree"
  "values2tree"
  "values2treeEx"

  ;;
  "mapAsync"
  ;; Pair, Triple, Quadruple
  "unpair"
  "unpairC"
  "untriple"
  "untripleC"
  "unquadruple"
  "unquadrupleC"
  "firstOfPair"
  "secondOfPair"
  "firstOfTriple"
  "secondOfTriple"
  "thirdOfTriple"
  "firstOfQuadruple"
  "secondOfQuadruple"
  "thirdOfQuadruple"
  "fourthOfQuadruple"

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

(defconst a9flow-font-lock-keywords
  ;; the order of the rules is taken into account!
  ;; use case-sensive search mode, by set properly font-lock-defaults flags
  `(
    ("\\b[0-9]+\\b" . font-lock-constant-face) ;; numeric literals
    ("|>" . font-lock-builtin-face) ;; pipe
    (,(regexp-opt a9flow-keywords 'words) . 'font-lock-keyword-face)
    (,(regexp-opt a9flow-builtins 'words) . 'font-lock-builtin-face)
    (,(regexp-opt a9flow-types 'words) . 'font-lock-type-face)

    ;; structur constructors, unions (started from A-Z) and  global definitions in upper-case 
    ("\\<[A-Z][A-Za-z0-9_]*\\>"   . 'font-lock-type-face)

    ;; fontify x in local declarations like:   x : Foo = ...
    ("^\\s-*\\(\\<\\(\\sw\\|\\s_\\)+\\>\\) *\\(:[^=\n]+\\)?=" (1 'font-lock-variable-name-face))
 
    ;; hexcolour-keywords
    ("0x\\([abcdefABCDEF[:digit:]]\\{6\\}\\)"
      (0 (put-text-property (match-beginning 0)
                            (match-end 0)
                            'face (list :background
                                        (progn
                                          ;; (message (concat "#" (match-string-no-properties 1)))
                                          (concat "#" (match-string-no-properties 1)))))))
    )
    
  "Expressions to highlight in A9Flow mode.")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;###autoload
(define-derived-mode a9flow-mode prog-mode "A9Flow"
  "Major mode for editing a9flow code.\\<a9flow-mode-map>"
  (setq-local comment-start "//")
  (setq-local comment-end "")
  (setq-local parse-sexp-ignore-comments t)
  (setq-local font-lock-defaults '(a9flow-font-lock-keywords nil nil)) ;; case-sensitive search, it's nessassery for types constructor search
  (setq-local indent-line-function 'a9flow-indent-line)
  (setq-local tab-width 4)
  (a9flow-register-compilation-error-regexp)
)
;; compilation mode ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun a9flow-register-compilation-error-regexp ()
  (let ((form '(a9flow "^\\(.+?\\):\\([0-9]+\\):\\([0-9]+\\):" 1 2)))

      (if (assq 'a9flow compilation-error-regexp-alist-alist)
	  (setf (cdr (assq 'a9flow compilation-error-regexp-alist-alist)) (cdr form))
	(push form compilation-error-regexp-alist-alist))

      (push 'a9flow compilation-error-regexp-alist)
  ))


