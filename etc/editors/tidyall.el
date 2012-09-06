;;; tidyall.el -- Apply tidyall (https://metacpan.org/module/tidyall) to the current buffer

;; Copyright (C) 2012  Jonathan Swartz

;; Author: Jonathan Swartz <swartz@pobox.com>
;; Keywords: extensions
;; Status: Tested with Emacs 24.1.1

;; This file is *NOT* part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.


;; This package implements a single function, tidyall-buffer, which
;; runs tidyall (https://metacpan.org/module/tidyall) on the current buffer.

;; If successful, the contents of the buffer are replaced with the tidied contents, and
;; the buffer is saved if tidyall-autosave is true.  The modifications should be
;; undoable.

;; If tidyall generates any errors, the buffer is not changed, and a separate window
;; called *tidyall-output* is opened displaying the error.

;; To operate on just a region of the buffer, use narrow-to-region.

;; To assign this command to ctrl-t in perl-mode and pod-mode:
;;
;;   (setq perl-mode-hook
;;        '(lambda ()
;;           (local-set-key "\C-t" 'tidyall-buffer)
;;           ))
;;   
;;   (setq pod-mode-hook
;;        '(lambda ()
;;           (local-set-key "\C-t" 'tidyall-buffer)
;;           ))
;;
;; or to assign it globally:
;;
;;   (global-set-key "\C-t" 'tidyall-buffer)
;;
;; (This replaces the default binding to transpose-chars, which I never use but ymmv.)

;; The variable `tidyall-cmd` contains the path to the tidyall command.
;;
(setq tidyall-cmd "tidyall")

;; The variable `tidyall-autosave` indicates whether to save the buffer after a successful
;; tidy - defaults to t
;;
(setq tidyall-autosave t)

(defun tidyall-buffer ()
  "Run tidyall on the current buffer."
  (interactive)
  (let ((file (buffer-file-name)))
    (cond ((null file)
           (message "buffer has no filename"))
          (t
           (let* ((command (concat tidyall-cmd " -m editor --pipe " file))
                  (tidyall-buffer (get-buffer-create "*tidyall-output*"))
                  (start (point-min))
                  (end (point-max))
                  (orig-window-start (window-start (selected-window)))
                  (orig-point (point)))
             (with-current-buffer tidyall-buffer (erase-buffer))
             (let* ((result
                     (call-process-region
                      start end shell-file-name nil
                      (list tidyall-buffer t) nil shell-command-switch command))
                    (output (with-current-buffer tidyall-buffer (buffer-string))))
               (cond ((zerop result)

                      ;; Success. Replace content if it changed
                      ;;
                      (cond ((not (equal output (buffer-string)))
                             (delete-region start end)
                             (insert output)

                             ;; Restore original window start and point as much as
                             ;; possible. Go to beginning of line since we'll probably be
                             ;; at a random point around our original line after the tidy.
                             ;;
                             (set-window-start (selected-window) orig-window-start)
                             (goto-char orig-point)
                             (beginning-of-line)
                             (when tidyall-autosave
                               (save-buffer))
                             (message (concat "tidied " file)))
                            (t
                             (message (concat "checked " file)))))
                     (t
                      ;; Error. Display in other window
                      ;;
                      (when (< (length (window-list)) 2)
                        (split-window-vertically))
                      (set-window-buffer (next-window) tidyall-buffer)))))))))
