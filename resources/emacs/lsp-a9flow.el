;; lsp-a9flow.el --- register a LSP client for a9flow language server -*- lexical-binding:t -*-

;; Copyright (C) 2024 Evgeniy Turishev

;; Author: Evgeniy Turishev evgeniy.turishev@area9.dk

;; This file is not part of GNU Emacs.

;;; License:

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;;; Commentary:

;; to start LSP mode for a9flow after the client rigistration:
;;   M-x lsp-mode
;;
;; add something like this to your init.el file to start mode on open .flow files:
;;

;; (use-package lsp-a9flow
;;   :ensure nil
;;   :defer nil
;;   :init
;;   (setq lsp-a9flow-langserver-command
;; 	'("java"
;; 	  "-jar"
;; 	  "-Xss32m" "-Xms256m" "-Xmx1g"
;; 	  "/home/work/area9/flow9/tools/flowc_lsp/flowc_lsp.jar"
;; 	  )))
;;
;; (use-package a9flow-mode
;;   :ensure nil
;;   :mode ("\\.flow$" . a9flow-mode)
;;   :config
;;   (require 'lsp-a9flow) ;; register client before LSP mode will be used
;;   :hook (
;; 	 (a9flow-mode . lsp-mode)))
;;
;; at now most of LSP mode features depened on runned http a9flow compiler:
;; user$ flowc1 server-mode=http

(require 'lsp-mode)


(defvar lsp-a9flow-langserver-command nil
  "any value that is suitable for lsp-stdio-connection: string (command), list of strings (commnad arg1 ...) or fn")


(add-to-list 'lsp-language-id-configuration '(a9flow-mode . "a9flow"))

(lsp-register-client (make-lsp-client
		      :new-connection (lsp-stdio-connection lsp-a9flow-langserver-command)
		      :activation-fn (lsp-activate-on "a9flow")
		      :server-id 'flowc_lsp))

(provide 'lsp-a9flow)
;;; lsp-a9flow.el ends here
