;; a9flow-compiler.el
;; a9flow-compiler minor mode
;; 
;; Manage (start, kill, restart, clean) flowc http-server.
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

;; Customazing
;; set a custom command to run the compiler server as a list command-name and args
;; like
;;  '("flowc1" "server-mode=http")
;; or
;;  '("java" "-jar" "-Xss32m" "-Xms256m" "-Xmx8g" "/home/work/area9/flow9/tools/flowc/flowc.jar" "server-mode=http")
;;
;; set clean objects command (used in restart also):
;; (setq a9flow-compiler-clean-cmd "rm -fR /home/work/area9/flow9/objc")

;; M-x a9flow-compiler-mode
;; M-x a9flow-start-http-server
;; M-x a9flow-kill-http-server
;; M-x a9flow-restart-http-server
;; M-x a9flow-compiler-clean


(provide 'a9flow-compiler)

(defvar a9flow-project-dir nil "a9flow default directory")

(defconst a9flow-http-server-name "a9flow-http-server")
(defconst a9flow-compiler-default-cmd '("flowc1" "server-mode=http"))
(defconst a9flow-compiler-clean-cmd nil)


(defvar a9flow-compiler-run-server-cmd nil
  "can be a list of command-name and its args, that can used in make-process as :command arg"
  )

(defvar a9flow-http-server-status 'x)

(defun a9flow-http-server-upd-status (process event)
  (let* ((status (process-status process))
	 (status-sym (cond 
		      ((eq status 'run) 'ok)
		      ((eq status 'signal) 'x)
		      ((eq status 'exit) 'x)
		      ((null status) 'x)
		      (t '\?))))
    (setq a9flow-http-server-status status-sym)
    (message "Process %s had the event: %s" process event)
    (message "Process %s status: %s" process status-sym)))


(defun add-http-server-sentinel-after (fn)
  (let* ((process (get-process a9flow-http-server-name))
	 (old-sentinel (process-sentinel process)))
    (set-process-sentinel process
			  (add-function :after old-sentinel fn))))


(defun a9flow-http-server-get-status ()
  (process-status a9flow-http-server-name))

(defun a9flow-start-http-server ()
  (interactive)
  (if (a9flow-http-server-get-status)
      (message "a9flow http server already running, ignored")
    (let ((cmd (if (null a9flow-compiler-run-server-cmd)
		   a9flow-compiler-default-cmd
		 a9flow-compiler-run-server-cmd)))
      (message "a9flow http server start")
      (let ((process (make-process
		     :name a9flow-http-server-name
		     :buffer a9flow-http-server-name
		     :command cmd
		     :sentinel (lambda (process event)
				 (internal-default-process-sentinel process event)
				 (a9flow-http-server-upd-status process event)))))
	(a9flow-http-server-upd-status process nil)
	))))

(defun a9flow-kill-http-server ()
  (interactive)
  (if (a9flow-http-server-get-status)
      (progn
	(message "a9flow http server stop")
	(kill-process (get-buffer-process a9flow-http-server-name)))
    (message "a9flow http server is not running, ignored")))


(defun a9flow-compiler-clean ()
  (interactive)
  (when (stringp a9flow-compiler-clean-cmd)
    (message "a9flow compiler clean")
    (call-process-shell-command a9flow-compiler-clean-cmd)))


(defun a9flow-restart-http-server ()
  (interactive)
  (when (a9flow-http-server-get-status)
    ;; (add-http-server-sentinel-after (lambda (process event)
    ;; 				      (message "Process %s had the event: %s" process event)))
    (a9flow-kill-http-server)
    (sleep-for 1)
    (a9flow-compiler-clean)
    (sleep-for 1))
  (a9flow-start-http-server))


(defvar a9flow-compiler-mode-map
  (let ((map (make-sparse-keymap)))
    map)
  "Map for `a9flow-compiler-mode`")


(defun a9flow-compiler-lighter-format (status-sym)
  (let ((fc (if (eq status-sym 'ok) 'success 'error)))
    (propertize
     (concat " a9flow-http:" (symbol-name status-sym))
     'face fc)))

;;;###autoload
(define-minor-mode a9flow-compiler-mode
  "run and manage a9flow compiler http-server"
  :global t
  :init-value nil
  :lighter (:eval (a9flow-compiler-lighter-format a9flow-http-server-status))
  :keymap a9flow-compiler-mode-map

  (progn
    (message "a9flow-compiler-mode autoload: %s" a9flow-compiler-mode)
    (if a9flow-compiler-mode
	(a9flow-start-http-server)
      (a9flow-kill-http-server))))

