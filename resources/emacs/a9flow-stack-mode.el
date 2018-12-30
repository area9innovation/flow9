(defun a9flow-stack-format ()
  (interactive)
  (goto-char 1)
  (replace-string "\"" "")
  (goto-char 1)
  (replace-string "nCalled" "\nCalled")
  )

(defun a9flow-stack-entry-navigate (&optional do-switch-window)
  (interactive)
  (setq line (buffer-substring-no-properties (line-beginning-position) (line-end-position)))
  (if (string-match "Called from .*\\s(\\([a-zA-Z0-9_/]+.flow\\) line \\([0-9]+\\)\\s)" line)
      (a9flow-navigate-stack-entry
       (match-string 1 line)
       (string-to-number (match-string 2 line))
       do-switch-window)
      (if (string-match "at .*\\s(\\([a-zA-Z0-9_/]+.flow\\):\\([0-9]+\\)\\s)" line)
          (a9flow-navigate-stack-entry
           (match-string 1 line)
           (string-to-number (match-string 2 line))
           do-switch-window)
        (if (string-match "\\([a-zA-Z0-9_/]+.flow\\):\\([0-9]+\\):" line)
            (a9flow-navigate-stack-entry
             (match-string 1 line)
             (string-to-number (match-string 2 line))
             do-switch-window)
          (message "Fail")))))

(defun a9flow-stack-entry-navigate-with-switch ()
  (interactive)
  (a9flow-stack-entry-navigate 1))

(defvar a9flow-stack-mode-hook nil)

(defun a9flow-navigate-stack-entry (file-path line-num do-switch-window)
  (find-file-other-window (concat a9flow-basedir "/" file-path))
  (goto-line line-num)
  (if (not do-switch-window)
      (previous-multiframe-window)))

(define-derived-mode a9flow-stack-mode
  text-mode
  "A9FlowStack"
  "Area9 flow call stack"
  )

(provide 'a9flow-stack-mode)

(add-hook 'a9flow-stack-mode-hook
          (lambda ()
            (local-set-key (kbd "s") 'a9flow-stack-entry-navigate)
            (local-set-key (kbd "g") 'a9flow-stack-entry-navigate-with-switch)
            (local-set-key (kbd "f") 'a9flow-stack-format)))
