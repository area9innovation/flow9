;; At first you should load a9flow-mode:
;;   (require 'a9flow-mode)

;; When specifying directories, be sure not to omit the trailing
;; backslash (Windows) or slash (Mac/Linux) character.
;;
;; Specify area9 code base directory
;;   (almost all relative paths will be calculated with it):
;;   (setq a9flow-basedir "d:\\work\\area9\\svn\\")
;; Specify include directories:
;;   (setq a9flow-include-dirs '("d:\\work\\area9\\svn\\"
;;                               "d:\\work\\area9\\flow-svn\\lib\\"))
;; Specify a path to the flow compiler (svn root):
;;   (setq a9flow-compiler-basedir "d:\\work\\area9\\flow-svn\\")

;; Configure project list:
;;   (setq a9flow-projects
;;         '(("program" "program/program.flow" ("--js program.js" "--debug")))
;;   First element is a project name (you will enter it when you compile a project)
;;   Second element is an input file relative path
;;   Third one - argument list
;;

;; flow
(require 'a9flow-mode)
(setq auto-mode-alist
      (append '(("\\.flow$" . a9flow-mode)) auto-mode-alist))
(setq a9flow-basedir "d:\\work\\area9\\svn\\")
(setq a9flow-include-dirs '("d:\\work\\area9\\svn\\" "d:\\work\\area9\\flow-svn\\lib\\"))
(setq a9flow-compiler-basedir "d:\\work\\area9\\flow-svn\\")
(setq a9flow-projects
      '(("test" "test.flow" ("--swf test.swf" "--debug"))
        ))
(add-hook 'a9flow-mode-hook
          (lambda ()
            (setq tab-width 2)
            (setq hide-region-before-string "")
            (setq hide-region-after-string "")
            (local-set-key (kbd "C-c a") 'a9flow-compile)
            (local-set-key (kbd "C-c p") 'a9flow-compile-project-ido)
            (local-set-key (kbd "C-c r") 'a9flow-run-buffer)
            (local-set-key (kbd "C-c t") 'a9flow-run-project-ido)
            (local-set-key (kbd "C-.") 'a9flow-history-point)
            (local-set-key (kbd "M-.") 'a9flow-goto-definition)
            (local-set-key (kbd "M-,") 'a9flow-go-back)
            (local-set-key (kbd "M-;") 'a9flow-goto-function-body)
            (local-set-key (kbd "M-s f") 'a9flow-find-word)
            (local-set-key (kbd "M-s u") 'a9flow-find-usages))
          )
;; you probably wouldn't want this most of the time, but ymmv
;; (add-hook 'a9flow-mode-hook 'whitespace-mode)
