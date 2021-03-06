;;; swipe.el --- use swiping gesture                 -*- lexical-binding: t; -*-

;; Copyright (C) 2011-2014  Leo Liu

;; Author: Leo Liu <sdl.web@gmail.com>
;; Version: 1.0
;; Keywords: tools, convenience
;; Created: 2011-11-10

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Use swiping gesture to move forward/backward sensibly.

;;; Code:

(require 'cl-lib)

(eval-and-compile
  (or (fboundp 'user-error)             ;New in emacs 24.3
      (defalias 'user-error 'error))

  (or (fboundp 'mac-start-animation)    ;New in Mac Port 2.91
      (defalias 'mac-start-animation 'ignore)))

(defun swipe-buffer-hidden-p (buffer)
  ;; See also `get-next-valid-buffer'.
  (string-prefix-p " " (if (bufferp buffer) (buffer-name buffer) buffer)))

(defvar swipe-mode-alist
  '((help-mode help-go-forward help-go-back)
    (Info-mode Info-history-forward Info-history-back)
    (eww-mode eww-forward-url eww-back-url)
    (rcirc-mode swipe-rcirc-next-buffer t)
    (w3m-mode w3m-view-next-page w3m-view-previous-page)
    (slime-inspector-mode nil slime-inspector-pop)
    (rfcview-mode nil pop-to-mark-command))
  "An associated list of the form (MAJOR-MODE FORWARD-FN BACKWARD-FN).
FORWARD-FN and BACKWARD-FN can be t to use the default value.")

(defvar swipe-forward-function 'swipe-next-same-buffer
  "Function used by `swipe-forward' to do the work.")

(defvar swipe-backward-function 'swipe-prev-same-buffer
  "Function used by `swipe-backward' to do the work.")

(defun swipe-forward-function ()
  (if (local-variable-p swipe-forward-function)
      swipe-forward-function
    (pcase (cl-some (lambda (x)
                      (and (derived-mode-p (car x)) x))
                    swipe-mode-alist)
      (`nil 'swipe-next-same-buffer)
      (`(,_ t . ,_) 'swipe-next-same-buffer)
      (`(,_ ,f . ,_) f))))

(defun swipe-backward-function ()
  (if (local-variable-p swipe-backward-function)
      swipe-backward-function
    (pcase (cl-some (lambda (x)
                      (and (derived-mode-p (car x)) x))
                    swipe-mode-alist)
      (`nil 'swipe-prev-same-buffer)
      (`(,_ ,_ t) 'swipe-prev-same-buffer)
      (`(,_ ,_ ,b) b))))

(defun swipe-forward (event)
  (interactive "e")
  (with-selected-window (posn-window (event-start event))
    (let ((buf (current-buffer))
          (tick (buffer-chars-modified-tick))
          (forward-fn (swipe-forward-function)))
      (and (functionp forward-fn) (funcall forward-fn))
      (unless (and (eq buf (current-buffer))
                   (= tick (buffer-chars-modified-tick)))
        (mac-start-animation (selected-window) :direction 'right)))))

(defun swipe-backward (event)
  (interactive "e")
  (with-selected-window (posn-window (event-start event))
    (let ((buf (current-buffer))
          (tick (buffer-chars-modified-tick))
          (backward-fn (swipe-backward-function)))
      (and (functionp backward-fn) (funcall backward-fn))
      (unless (and (eq buf (current-buffer))
                   (= tick (buffer-chars-modified-tick)))
        (mac-start-animation (selected-window) :direction 'left)))))

(defun swipe-next-same-buffer ()
  "Switch to next buffer with the same major mode."
  (cl-loop for b in (delete (current-buffer) (buffer-list))
           when (and (eq major-mode (buffer-local-value 'major-mode b))
                     (not (swipe-buffer-hidden-p b)))
           do (bury-buffer (current-buffer)) (switch-to-buffer b)
           (cl-return b)
           finally (user-error "No next `%s' buffer" major-mode)))

(defun swipe-prev-same-buffer ()
  "Switch to previous buffer with the same major mode."
  (cl-loop for b in (nreverse (delete (current-buffer) (buffer-list)))
           when (and (eq major-mode (buffer-local-value 'major-mode b))
                     (not (swipe-buffer-hidden-p b)))
           do (switch-to-buffer b)
           (cl-return b)
           finally (user-error "No previous `%s' buffer" major-mode)))

(defvar swipe-mode-map
  (let ((m (make-sparse-keymap)))
    (define-key m [swipe-left]  'swipe-backward)
    (define-key m [swipe-right] 'swipe-forward)
    m))

;;;###autoload
(define-minor-mode swipe-mode nil :global t)

(defvar rcirc-activity)
(defvar rcirc-track-minor-mode)
(declare-function rcirc-next-active-buffer "rcirc")
(defun swipe-rcirc-next-buffer ()
  (if (and rcirc-activity rcirc-track-minor-mode)
      (progn (bury-buffer) (rcirc-next-active-buffer nil))
    (swipe-next-same-buffer)))

(provide 'swipe)
;;; swipe.el ends here
