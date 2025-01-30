;; a9flow-config-lsp-example.el

;; This configuration is relevant to work with lsp-mode.


(use-package compile-target
  :ensure nil
  :config
  :bind (("<f8>tm" . compile-target-mode)
	 :map compile-target-mode-map
	 ("C-c t" . compile-target-compile-ivy)
	 ("C-c c" . compile-target-compile-default)
	 ("<f8>to" . compile-target-open-project)
	 ("<f8>tt" . compile-target-compile-ivy)
	 ("<f8>tc" . compile-target-compile-default)
	 ("<f8>ta" . compile-target-add)
	 ("<f8>td" . compile-target-set-dir)))


(use-package lsp-mode
  :defer t
  :hook (lsp-mode . lsp-enable-which-key-integration)
  :custom
  (lsp-keymap-prefix "C-c l")
  (lsp-enable-symbol-highlighting nil)
  (lsp-ui-doc-enable nil)
  (lsp-completion-enable t)
  (lsp-completion-provider :none)
  (lsp-completion-enable-additional-text-edit nil)
  (lsp-enable-snippet nil)
  (lsp-completion-show-kind nil)
  (lsp-enable-indentation nil)
  (lsp-lens-enable nil))


(use-package lsp-a9flow
  :ensure nil
  :defer t
  :init
  (setq lsp-a9flow-langserver-command
	'("java"
	  "-jar"
	  "-Xss32m" "-Xms256m" "-Xmx1g"
	  "/home/work/area9/flow9/tools/flowc_lsp/flowc_lsp.jar"))
  :hook (a9flow-mode . (lambda ()
			 (require 'lsp-a9flow)
			 (lsp))))


(use-package a9flow-compiler
  :ensure nil
  :config
  (setq  a9flow-compiler-clean-cmd "rm -fR /home/work/area9/flow9/objc")
  :bind (("<f9>rc" . a9flow-compiler-mode)
	 :map a9flow-compiler-mode-map
	 ("<f8>cs" . a9flow-start-http-server)
	 ("<f8>ck" . a9flow-kill-http-server)
	 ("<f8>cr" . a9flow-restart-http-server)
	 ("<f8>cc" . a9flow-compiler-clean)))


(use-package a9flow-mode
  :ensure nil
  :mode ("\\.flow$" . a9flow-mode)
  :config
  (require 'a9flow-debug-print)
  (which-function-mode t)
  :hook (a9flow-mode . compile-target-mode)
  :bind (:map a9flow-mode-map
	      ("<f8>pp" . a9flow-debug-print-var)
	      ("<f8>po" . a9flow-debug-print-name)
	      ("<f8>pm" . a9flow-debug-print-map)
	      ("<f8>pt" . a9flow-debug-print-transform)
	      ("<f8>ps" . a9flow-debug-print-subscribe)))


