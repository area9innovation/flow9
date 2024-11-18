;; a9flow-config-example.el

;; This configuration is relevant to work without lsp-mode.
;; Note that lsp-mode provides more features and comfort in a a9flow workflow.


(use-package compile-target
  :ensure nil
  :config
  :bind (
	 ("<f8>tm" . compile-target-mode)
	 :map compile-target-mode-map
	 ("C-c t" . compile-target-compile-ivy)
	 ("C-c c" . compile-target-compile-default)
	 ("<f8>to" . compile-target-open-project)
	 ("<f8>tt" . compile-target-compile-ivy)
	 ("<f8>tc" . compile-target-compile-default)
	 ("<f8>ta" . compile-target-add)
	 ("<f8>td" . compile-target-set-dir)
	 )
  )


(use-package a9flow-compiler
  :ensure nil
  :config
  (setq  a9flow-compiler-clean-cmd "rm -fR /home/work/area9/flow9/objc")
  :bind (
	 :map a9flow-compiler-mode-map 
	 ("<f8>cs" . a9flow-start-http-server)
	 ("<f8>ck" . a9flow-kill-http-server)
	 ("<f8>cr" . a9flow-restart-http-server)
	 ("<f8>cc" . a9flow-compiler-clean)
	 )
  )


(use-package a9flow-mode
  :ensure nil
  :mode ("\\.flow$" . a9flow-mode)
  :config
  (require 'a9flow-debug-print)
  (require 'a9flow-goto)
  :hook (
	 (a9flow-mode . compile-target-mode)
	 (a9flow-mode . (lambda ()
			  (setq compile-target-after-open-project
				(lambda () ;; let a9flow-goto to know where it should run the compiler 
				  (setq a9flow-goto-project-dir compile-target-project-directory)))))
	 )
  :bind (
	 :map a9flow-mode-map
	      ("<f8>cm" . a9flow-compiler-mode) ;; activate compiler mode - run http server
	      ("M-." . a9flow-goto-definition)
	      ("M-," . a9flow-go-back)
	      ("<f8>pp" . a9flow-debug-print-var)
	      ("<f8>po" . a9flow-debug-print-name)
	      ("<f8>pm" . a9flow-debug-print-map)
	      ("<f8>pt" . a9flow-debug-print-transform)
	      ("<f8>ps" . a9flow-debug-print-subscribe)
	 )
  )

