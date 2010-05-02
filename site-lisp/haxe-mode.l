;; -*- Mode: Lisp; -*- -------------------------------------------------
;;
;; Title:   haxe-mode, A Xyzzy major mode for the haXe language
;; Author:  Daichi Shinozaki <shinozaki.daichi@classmethod.jp>
;; Date:    01/May/2010
;; URL:     http://github.com/dseg/haxe-mode-for-xyzzy
;; SeeAlso: http://haxe.org/doc/start
;; License: MIT
;;
;; $Id$
;;
;; Versions:
;;    0.1 - Initial release, some syntax-hilighting only.
;;
;; Usage:
;;  Include something like this in your .xyzzy
;;
;; (require "haxe-mode")
;; (push '("\\.hx$" . haxe-mode) *auto-mode-alist*)
;;
;; Note:
;;  You need haxe v2.06 or later for code-completion.
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
         *haxe-mode-map*
         haxe-indent-line
         haxe-newline-and-indent
         haxe-completion))

; constants, variable
(defconstant *haxe-mode-version* "0.1" "haxe-mode: version")
(defvar *haxe-indent-level*                               2)
(defvar *haxe-continued-line-offset*                      2)
(defvar *haxe-label-offset*                              -2)
(defvar *haxe-tab-always-indent*                          t)
(defvar *haxe-mode-hook*                                nil)
(defvar *haxe-comment-column*                           nil)
(defvar *haxe-popup-completion-list*                      t)
(defvar *haxe-string-face*                      '(:color 9))
(defconstant haxe-completion-buffer-name           "*haxe*")
(defconstant haxe-empty-completion-result-regex
  (compile-regexp "<list>\\r?\\n</list>"))

; keymap
(defvar *haxe-mode-map* nil)
(unless *haxe-mode-map*
  (setq *haxe-mode-map* (make-sparse-keymap))
  (define-key *haxe-mode-map* #\TAB 'haxe-indent-line)
  (define-key *haxe-mode-map* #\RET 'haxe-newline-and-indent)
  (define-key *haxe-mode-map* #\#   'c-electric-insert)
  (define-key *haxe-mode-map* #\}   'c-electric-close)
  (define-key *haxe-mode-map* #\C-h 'backward-delete-char-untabify-or-selection))
  (define-key *haxe-mode-map* #\C-. 'haxe-completion)
  (define-key *haxe-mode-map* #\C-M-q 'indent-sexp)

; regex keyword
(defvar *haxe-regexp-keyword-list*
  (compile-regexp-keyword-list
   `(("'[^']*'"    t ,*haxe-string-face* :string)
     ("\"[^\"]*\"" t ,*haxe-string-face* :string)))
  "haxe-mode: regex keyword list")

; keyword
(defvar *haxe-keyword-hash-table* nil)
(defvar *haxe-keyword-file* "haXe")

; syntax table
(defvar *haxe-mode-syntax-table* nil)
(unless *haxe-mode-syntax-table*
  (setq *haxe-mode-syntax-table* (make-syntax-table))
  (do ((x #x21 (1+ x)))
      ((>= x #x7f))
    (let ((c (code-char x)))
      (unless (alphanumericp c)
    (set-syntax-punctuation *haxe-mode-syntax-table* c))))
  (set-syntax-string *haxe-mode-syntax-table*                #\")
  (set-syntax-string *haxe-mode-syntax-table*                #\')
  (set-syntax-symbol *haxe-mode-syntax-table*                #\_)
  (set-syntax-symbol *haxe-mode-syntax-table*                #\#)
  (set-syntax-match  *haxe-mode-syntax-table*            #\( #\))
  (set-syntax-match  *haxe-mode-syntax-table*            #\{ #\})
  (set-syntax-match  *haxe-mode-syntax-table*            #\[ #\])
  (set-syntax-start-multi-comment *haxe-mode-syntax-table*  "/*")
  (set-syntax-end-multi-comment   *haxe-mode-syntax-table*  "*/")
  (set-syntax-start-c++-comment   *haxe-mode-syntax-table*   #\/)
  (set-syntax-end-c++-comment     *haxe-mode-syntax-table* #\LFD))

; mode abbrev
(defvar *haxe-mode-abbrev-table* nil)
(unless *haxe-mode-abbrev-table*
  (define-abbrev-table '*haxe-mode-abbrev-table*))

; indent
(defun haxe-indent-line ()
  (interactive "*p")
  (c-indent-line))

(defun haxe-newline-and-indent (&optional (arg 1))
  (interactive "*p")
  (delete-trailing-spaces)
  (insert #\LFD arg)
  (haxe-indent-line))

; code completion
; http://ncannasse.fr/blog/haxe_completion
(defun haxe-completion ()
  (interactive)
  (let* ((fspec (get-buffer-file-name))
         (bytepos (+ (point) (1- (get-bytecount-of-lines))))
         ; cmd is something like:
         ;   haxe.exe test.hx --display "c:/devel/haxe/test.hx"@71
         (cmd (format nil "haxe.exe ~a --display \"~a\"@~d"
                      (file-namestring fspec) fspec bytepos))
         (curdir (default-directory))
         (keyword-xml nil)
         (word-list nil))
    (save-window-excursion
      (with-output-to-temp-buffer (haxe-completion-buffer-name nil)
        (execute-shell-command cmd t haxe-completion-buffer-name t curdir)
        (setq keyword-xml (buffer-substring (point-min) (point-max)))
        (unless (string-match haxe-empty-completion-result-regex keyword-xml)
          (setq word-list (xmlpm-parse keyword-xml)))
        ))
    (if word-list
        (let ((keyword-list (format-haxe-proposed-keyword-list
                             (nthcdr 2 (car word-list))))
              (opoint (point)))
          (do-completion opoint opoint :list keyword-list nil nil keyword-list)
          ))))

(defun format-haxe-proposed-keyword-list (keywords)
  (let ((result nil))
    (dolist (keyword keywords
                     result)
      (let ((intf (cdaadr keyword))
            (type (third (caddr keyword)))
            (desc (second (cadddr keyword)))
            (compl-item nil))
        (setq compl-item
              (concat
               (or intf nil)
               (and type (or (concat "(" type ")") nil))
               (and desc (or (concat "[" desc "]") nil))))
        (push compl-item result)
        ))))

; internal helper functions
(defun get-bytecount-of-lines ()
  (let ((eol (buffer-eol-code)))
    (cond 
     ((eq eol *eol-lf*) 0)
     ((eq eol *eol-cr*) 0)
     ((eq eol *eol-crlf*) (current-line-number)))))

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
  (make-local-variable 'regexp-keyword-list)
  (setq regexp-keyword-list *haxe-regexp-keyword-list*)
  (and *haxe-keyword-file*
       (null *haxe-keyword-hash-table*)
       (setq *haxe-keyword-hash-table*
         (load-keyword-file *haxe-keyword-file* t)))
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
  (run-hooks '*haxe-mode-hook*))

;;; haxe-mode.l ends here
