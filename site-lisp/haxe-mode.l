;; -*- Mode: Lisp; Package: EDITOR -*- ---------------------------------
;;
;; Title:   haxe-mode, A Xyzzy major mode for the haXe language
;; Author:  Daichi Shinozaki <shinozaki.daichi@classmethod.jp>
;; Date:    ??/May/2010
;; URL:     http://github.com/dseg/haxe-mode-for-xyzzy
;; SeeAlso: http://haxe.org/doc/start
;; License: MIT
;;
;; Versions:
;;    0.1 - Initial release, syntax-hilighting & code completion support.
;;
;; Usage:
;;  Include something like this in your .xyzzy
;;
;; (require "haxe-mode")
;; (push '("\\.hx$" . haxe-mode) *auto-mode-alist*)
;;
;; Note:
;;  For code completion, you need xml-parser-modoki.l courtesy of Masashi Hattori.
;;  http://www7a.biglobe.ne.jp/~hat/xyzzy/dl.html
;;
;; TODO:
;; * tags support
;; * build support (*.hxml)
;; * package completion
;; * Static class member function completion
;;
;; Copyright (c) 2010 Daichi Shinozaki
;;
;; Permission is hereby granted, free of charge, to any person obtaining a copy
;; of this software and associated documentation files (the "Software"), to deal
;; in the Software without restriction, including without limitation the rights
;; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
;; copies of the Software, and to permit persons to whom the Software is
;; furnished to do so, subject to the following conditions:
;;
;; The above copyright notice and this permission notice shall be included in
;; all copies or substantial portions of the Software.
;;
;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
;; THE SOFTWARE.

;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

(provide "haxe-mode")

(in-package "editor")

(require "cc-mode")
(require "xml-parser-modoki")

(export '(haxe-mode
          *haxe-mode-abbrev-table*
          *haxe-mode-syntax-table*
          *haxe-indent-level*
          *haxe-continued-line-offset*
          *haxe-label-offset*
          *haxe-tab-always-indent*
          *haxe-mode-hook*
          *haxe-comment-column*
          *haxe-popup-completion-list*
          *haxe-regexp-keyword-list*
          *haxe-string-face*
          *haxe-regexp-face*
          *haxe-documentation-keyword-face*
          *haxe-mode-map*
          *haxe-mode-autosave-as-utf8*
          haxe-indent-line
          haxe-newline-and-indent
          haxe-completion))

; constants, variables
(defconstant *haxe-mode-version*             "0.1" "haxe-mode: version")
(defvar *haxe-indent-level*                                           2
  "")
(defvar *haxe-continued-line-offset*                                  2
  "")
(defvar *haxe-label-offset*                                          -2
  "")
(defvar *haxe-tab-always-indent*                                      t
  "")
(defvar *haxe-mode-hook*                                            nil
  "")
(defvar *haxe-comment-column*                                       nil
  "")
(defvar *haxe-popup-completion-list*                                  t
  "")
(defvar *haxe-string-face*                                  '(:color 9)
  "")
(defvar *haxe-ereg-face*                                    '(:color 1)
  "")
(defvar *haxe-documentation-keyword-face*                   '(:color 9)
  "")
(defvar *haxe-mode-autosave-as-utf8*                                nil
  "")
(defconstant haxe-completion-buffer-name                       "*haxe*"
  "")
(defconstant haxe-empty-completion-result-regex  "<list>\\r?\\n</list>"
  "")
(defconstant haxe-type-completion-result-regex "<type>\([^<]*\)</type>"
  "")

; keymap
(defvar *haxe-mode-map* nil)
(unless *haxe-mode-map*
  (setq *haxe-mode-map* (make-sparse-keymap))
  (define-key *haxe-mode-map* #\TAB   'haxe-indent-line)
  (define-key *haxe-mode-map* #\RET   'haxe-newline-and-indent)
  (define-key *haxe-mode-map* #\C-h   'backward-delete-char-untabify-or-selection)
  (define-key *haxe-mode-map* #\C-.   'haxe-completion)
  (define-key *haxe-mode-map* #\M-/   'haxe-completion)
  (define-key *haxe-mode-map* #\.     'haxe-electric-insert)
  (define-key *haxe-mode-map* #\(     'haxe-electric-insert)
  (define-key *haxe-mode-map* #\C-M-q 'indent-sexp)
;  (define-key *haxe-mode-map* '#\F1   'haxe-open-help)
  (define-key *haxe-mode-map* '(#\C-c #\d) 'haxe-insert-doc-comment))

; regexp
(defvar *haxe-beginning-of-defun-without-name-regexp*
  "\\<\\(?:\\(?:inline\\|override\\|public\\|private\\|static\\)[ \t]+\\)+function[ \t]+"
  "")

(defvar *haxe-beginning-of-defun-regexp*
  (compile-regexp
   (concat *haxe-beginning-of-defun-without-name-regexp* "[A-Za-z_][A-Za-z0-9_]+") t)
  "")

(defvar *haxe-singlequoted-string-regexp*
  "'[^\']*'"
  "")

(defvar *haxe-doublequoted-string-regexp*
  "\"[^\"]*\""
  "")

(defvar *haxe-doumentation-keyword-regexp*
  "@\\(?:author\\|copy\\|default\\|deprecated\\|eventType\\|example\\|exampleText\\|exception\\|haxe\\|inheritDoc\\|internal\\|link\\|param\\|private\\|return\\|see\\|serial\\|serialData\\|serialField\\|since\\|throws\\|usage\\|version\\)\\>"
  "")

(defvar *haxe-ereg-regexp*
  "~/[^/\\]*\\(?:[\\].[^/\\]*\\)*/[gimsu]\\{,4\\}"
  "")

(defvar *haxe-regexp-keyword-list*
  (compile-regexp-keyword-list
   `((,*haxe-singlequoted-string-regexp*  nil ,*haxe-string-face* :string)
     (,*haxe-doublequoted-string-regexp*  nil ,*haxe-string-face* :string)
     (,*haxe-doumentation-keyword-regexp* nil ,*haxe-documentation-keyword-face* :comment)
     (,*haxe-ereg-regexp* nil ,*haxe-ereg-face* nil)))
  "")

; tags
(pushnew '(haxe-maketags "*.hx") *maketags-list* :key #'car)

(defun haxe-maketags (file count)
  (goto-char (point-min))
  (while (scan-buffer *haxe-beginning-of-defun-regexp* :regexp t :case-fold t :tail t)
    (do-events)
    (format t "~A~A~D - ~A" (match-string 4) file (match-beginning 0) file)
    (incf count))
  count)

(defun tags-find-haxe-point (class name functionp point)
  (goto-char (- point *jump-tag-limit*))
  (and (scan-buffer (concat *basic-beginning-of-defun-without-name-regexp*
                            (regexp-quote name)
                            "[ \t]+")
                    :regexp t :case-fold t :limit (+ point *jump-tag-limit*))
       (point)))

; keyword
(defvar *haxe-keyword-hash-table* nil)
(defvar *haxe-keyword-file* "haXe")

; syntax table
(defvar *haxe-mode-syntax-table* nil
  "haxe-mode syntax table")
(unless *haxe-mode-syntax-table*
  (setq *haxe-mode-syntax-table* (make-syntax-table))
  (do ((x #x21 (1+ x)))
      ((>= x #x7f))
    (let ((c (code-char x)))
      (if (not (alphanumericp c))
        (set-syntax-punctuation *haxe-mode-syntax-table* c))))
  (set-syntax-string                 *haxe-mode-syntax-table* #\")
  (set-syntax-string                 *haxe-mode-syntax-table* #\')
  (set-syntax-symbol                 *haxe-mode-syntax-table* #\_)
  (set-syntax-symbol                 *haxe-mode-syntax-table* #\#)
  (set-syntax-match              *haxe-mode-syntax-table* #\( #\))
  (set-syntax-match              *haxe-mode-syntax-table* #\{ #\})
  (set-syntax-match              *haxe-mode-syntax-table* #\[ #\])
  (set-syntax-start-multi-comment  *haxe-mode-syntax-table*  "/*")
  (set-syntax-end-multi-comment    *haxe-mode-syntax-table*  "*/")
  (set-syntax-start-c++-comment    *haxe-mode-syntax-table*   #\/)
  (set-syntax-end-c++-comment      *haxe-mode-syntax-table* #\LFD)
  (set-syntax-escape               *haxe-mode-syntax-table*   #\\))

; mode abbrev
(defvar *haxe-mode-abbrev-table* nil)
(if (not *haxe-mode-abbrev-table*)
    (define-abbrev-table '*haxe-mode-abbrev-table*))

; indent
(defun haxe-indent-line ()
  ""
  (interactive "*p")
  (c-indent-line))

(defun haxe-newline-and-indent (&optional (arg 1))
  ""
  (interactive "*p")
  (delete-trailing-spaces)
  (insert #\LFD arg)
  (haxe-indent-line))

(defun haxe-electric-insert (&optional (arg 1))
  ""
  (interactive "*p")
  (self-insert-command arg)
  (haxe-indent-line))

(defun haxe-build-summary-of-functions ()
  ""
  (let ((result nil))
    (save-excursion
      (goto-char (point-min))
      (while
          (scan-buffer *haxe-beginning-of-defun-regexp*
          :regexp t :case-fold t :tail t)
        (push (list (current-line-number) (match-string 0)) result)))
    (nreverse result)))

; code completion
; http://ncannasse.fr/blog/haxe_completion
(defun haxe-completion ()
  ""
  (interactive "*")
  (let ((haxe-existp (haxe-exe-existp)))
    (unless haxe-existp
      (error "haxe.exe can not be located.
Please run 'haxesetup' in haxe installation and try again.")
      (return-from haxe-completion))
    (let* ((fspec (get-buffer-file-name))
           (bytepos (+ (point) (get-extra-bytecount-of-eol)))
           ; cmd is something like:
           ;   haxe.exe test.hx --display "c:/devel/haxe/test.hx"@71
           (cmd (format nil "haxe.exe --display \"~A\"@~D ~A"
                        fspec bytepos (file-namestring fspec)))
           (curdir (default-directory))
           (keyword-xml nil)
           (word-list nil))
      (save-window-excursion
        (with-output-to-temp-buffer (haxe-completion-buffer-name nil)
          (execute-shell-command cmd t haxe-completion-buffer-name t curdir)
          (setq keyword-xml (buffer-substring (point-min) (point-max)))
          (setq word-list
                (cond
                 ((string= "" keyword-xml) nil)
                 ((string-match haxe-empty-completion-result-regex keyword-xml) nil)
                 (t (xmlpm-parse keyword-xml))))))
      (when (string-not-equal "<" (substring keyword-xml 0 1))
        (popup-string (string-right-trim "\r\n" keyword-xml) (point))
        (return-from haxe-completion))
      (if (null word-list)
          (return-from haxe-completion))
      (let ((keyword-list (format-haxe-proposed-keyword-list (nthcdr 2 (car word-list))))
            (opoint (point)))
        (if keyword-list
            (popup-list
             keyword-list
             #'(lambda (item)
                 (if item
                     (let* ((oparen (string-matchp "(" item))
                            (methodp (numberp oparen)))
                       (if methodp
                           (progn
                             (insert (substring item 0 (1+ oparen)))
                             (popup-string item (+ opoint oparen)))
                         (insert item))
                       (refresh-screen)
                       )))))))))

(defun format-haxe-proposed-keyword-list (keywords)
  ""
  (let ((result nil))
    (dolist (keyword keywords
                     result)
      (let ((intf (cdaadr keyword))
            (type (third (caddr keyword)))
            (desc (second (cadddr keyword)))
            (compl-item nil))
        (setq compl-item
              (concat intf
                      (if type (concat "(" type ")") nil)
                      (if desc (concat "[" desc "]") nil)))
        (if compl-item
            (push compl-item result))
        ))))

(defun haxe-insert-doc-comment ()
  "Insert a documentation comment block."
  (interactive "*")
  (let ((beg (point))
        (end (point))
        (classp nil)
        (functionp nil)
        (indent-str nil))
    (save-excursion
      (when (next-line)
        (goto-bol)
        (setq beg (point))
        (skip-white-forward)
        (setq end (point))
        (setq classp (looking-at ".*\\<class\\>"))
        (setq functionp (or classp (looking-at ".*\\<function\\>")))
        (setq indent-str (buffer-substring beg end))))
    (let ((items (cond
                  (classp '("@author"))
                  (functionp '("@param" "@return"))
                  (t nil))))
      (progn (goto-bol)
        (if (looking-at "[ \t]+$")
            (kill-line)))
      (insert
       indent-str "/**\n"
       (if (null items)
           (concat indent-str " * \n")
         (format nil "~{~A * ~A \n~^~}"
                 (apply #'nconc
                        (mapcar #'list
                                (make-list (length items)
                                           :initial-element indent-str)
                                items))))
       indent-str " */")
      ; delete empty characters after "*/"
      (if (looking-at "[ \t]")
          (delete-region (point)
                         (progn (goto-eol) (point)))))))

;(defun haxe-open-help ()
;  (interactive)
;  (let (start end)
;    (multiple-value-bind (start end)
;        (get-selection-start-end)
;      (if start
;          (haxe-open-help-file (buffer-substring start end))))))

;(defun haxe-open-help-file (keyword)
;  (when (stringp keyword)
;    (let ((docdir (concat (si:getenv "HAXEPATH") "doc\\content\\"))
;          (name (concat keyword ".html")))
;      (if (and (boundp 'browswerex-installed-p) browserex-installed-p)
;          t ; TODO
;        (message-box (concat docdir name))
;        ;(shell-execute (concat docdir name))
;        ))))

; internal helper functions
(defun get-extra-bytecount-of-eol ()
  ""
  (let ((eol (buffer-eol-code)))
    (cond
     ((eq eol *eol-lf*) 0)
     ((eq eol *eol-cr*) 0)
     ((eq eol *eol-crlf*) (1- (current-line-number)))
     (t 0))))

(defun haxe-exe-existp ()
  "Check if the haxe executable exists."
  (file-exist-p (concat (si:getenv "HAXEPATH") "haxe.exe")))

; haxe-mode
(defun haxe-mode ()
  "Major mode for editing haxe code"
  (interactive)
  (kill-all-local-variables)
  (setq buffer-mode 'haxe-mode)
  (setq mode-name "haxe")
  (use-keymap *haxe-mode-map*)
  (use-syntax-table *haxe-mode-syntax-table*)
  (make-local-variable 'mode-specific-indent-command)
  (setq mode-specific-indent-command 'haxe-indent-line)
  (make-local-variable 'paragraph-start)
  (setq paragraph-start "^$\\|\f")
  (make-local-variable 'paragraph-separate)
  (setq paragraph-separate paragraph-start)
  (make-local-variable 'mode-specific-beginning-of-defun)
  (setq mode-specific-beginning-of-defun 'haxe-beginning-of-defun)
  (make-local-variable 'mode-specific-end-of-defun)
  (setq mode-specific-end-of-defun 'haxe-end-of-defun)
  (make-local-variable 'tags-find-target)
  (setq tags-find-target #'tags-find-target-simple)
  (make-local-variable 'tags-find-point)
  (setq tags-find-point #'tags-find-haxe-point)
  (make-local-variable 'build-summary-function)
  (setq build-summary-function 'haxe-build-summary-of-functions)
  (make-local-variable 'regexp-keyword-list)
  (setq regexp-keyword-list *haxe-regexp-keyword-list*)
  (and *haxe-keyword-file*
       (null *haxe-keyword-hash-table*)
       (setq *haxe-keyword-hash-table*
             (load-keyword-file *haxe-keyword-file* nil)))
  (when *haxe-keyword-hash-table*
    (make-local-variable 'keyword-hash-table)
    (setq keyword-hash-table *haxe-keyword-hash-table*))
  (setq *local-abbrev-table* *haxe-mode-abbrev-table*)
  (setq comment-start "// ")
  (setq comment-end "")
  (setq comment-start-skip "/\\(\\*+\\|/\\)[ \t]*")
  (setq comment-indent-function 'c-comment-indent)
  (when *haxe-comment-column*
    (setq comment-column *haxe-comment-column*))
  (when *haxe-mode-autosave-as-utf8*
    (make-local-variable '*before-save-buffer-hook*)
    (add-hook '*before-save-buffer-hook*
              #'(lambda ()
                  (if (change-fileio-encoding *encoding-utf8*) nil))))
  (run-hooks '*haxe-mode-hook*))

;;; haxe-mode.l ends here
