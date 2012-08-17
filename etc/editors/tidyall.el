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

;; More specifically, the function runs tidyall on the current file, outputting
;; its results to a temporary file; then replaces the contents of the current
;; buffer with the contents of the temporary file and saves the buffer.
;; Any modifications should be undoable.

;; If tidyall generates any errors, the buffer is not changed, and a separate window
;; called *tidyall-output* is opened displaying the error.

;; e.g. To assign this command to ctrl-t in perl-mode and pod-mode:
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

(defun tidyall-buffer ()
  "Run tidyall on the current file."
  (interactive)
  (let ((file (buffer-file-name)))
    (cond (file
           (if (buffer-modified-p)
               (save-buffer))
           (let* ((cmd (concat tidyall-cmd " --refresh-cache --output-suffix .tdy -m editor " file))
                  (tidyall-buffer (get-buffer-create "*tidyall-output*"))
                  (result (shell-command cmd tidyall-buffer))
                  (tidied-file (concat file ".tdy"))
                  (output (with-current-buffer tidyall-buffer (buffer-string)))
                  (window-positions (mapcar (lambda (w) (window-start w)) (window-list)))
                  (orig-point (point)))
             (when (string-match "[\t\n ]*$" output)
               (replace-match "" nil nil output))
             (cond ((zerop result)
                    (cond ((string-match "\\[tidied\\]" output)
                           (cond ((file-exists-p tidied-file)
                                  (erase-buffer)
                                  (insert-file-contents tidied-file)
                                  (delete-file tidied-file)
                                  (mapcar (lambda (w) (set-window-start w (pop window-positions))) (window-list))
                                  (goto-char orig-point)
                                  (save-buffer))
                                 (t
                                  (message (concat "Could not find '" tidied-file "'!")))))))
                   (t
                    (message nil)
                    (split-window-vertically)
                    (set-window-buffer (next-window) tidyall-buffer))))))))
