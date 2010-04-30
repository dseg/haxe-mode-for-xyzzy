;; -*- Mode: Lisp; Package: EDITOR; tab-width: 4 -*- -------------------
;;
;; Title:   haxe-mode, A Xyzzy major mode for the haXe language
;; Author:  Daichi Shinozaki <shinozaki.daichi@classmethod.jp>
;; Date:    01/May/2010
;; URL:     http://github.com/dseg/haxe-mode-for-xyzzy
;; SeeAlso: http://haxe.org/doc/start
;; License: MIT
;;
;; Versions:
;;    0.1 - Initial release, some syntax-hilighting only.
;;
;; Usage:
;;  Include something like this in your .xyzzy.
;;
;; (export 'ed::haxe-mode "ed")
;; (autoload 'haxe-mode "haxe-mode" t)
;; (pushnew '("\\.hx$" . haxe-mode) *auto-mode-alist* :test 'equal)
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

(export '(*haxe-mode-hook*
		  *haxe-mode-map* haxe-mode
		  *haxe-mode-abbrev-table*
		  *haxe-mode-syntax-table*
		  *haxe-indent-level*
		  *haxe-continued-line-offset*
		  *haxe-label-offset*
		  *haxe-tab-always-indent*
		  *haxe-auto-close*
		  *haxe-auto-cap*
		  *haxe-auto-correct-else-if*
		  *haxe-auto-correct-then*
		  *haxe-auto-correct-operators*
		  *haxe-comment-column*
		  *haxe-popup-completion-list*
		  haxe-indent-line
		  haxe-newline-and-indent
		  haxe-electric-close
		  haxe-electric-cap
		  haxe-forward-block
		  haxe-backward-block
		  haxe-beginning-of-defun
		  haxe-end-of-defun
		  haxe-correct-operators
		  haxe-indent-sexp
		  haxe-completion))
(require "cc-mode")

(defconstant *haxe-mode-version* "0.1" "haxe-mode: version")
(defvar *haxe-indent-level*            2)
(defvar *haxe-continued-line-offset*   2)
(defvar *haxe-label-offset*           -2)
(defvar *haxe-tab-always-indent*       t)
(defvar *haxe-mode-hook*             nil)
(defvar *haxe-comment-column*        nil)
(defvar *haxe-popup-completion-list* nil)

(defvar *haxe-mode-map* nil)
(unless *haxe-mode-map*
  (setq *haxe-mode-map* (make-sparse-keymap))
  (define-key *haxe-mode-map* #\TAB   'c-indent-line)
  (define-key *haxe-mode-map* #\RET   'c-newline-and-indent)
  (define-key *haxe-mode-map* #\#     'c-electric-insert)
  (define-key *haxe-mode-map* #\:     'c-electric-insert)
  (define-key *haxe-mode-map* #\}     'c-electric-close)
  (define-key *haxe-mode-map* #\C-h 'backward-delete-char-untabify-or-selection))
  (define-key *haxe-mode-map* '(#\ESC #\TAB) 'haxe-completion)
  (define-key *haxe-mode-map* #\C-M-q 'indent-sexp)

(defvar *haxe-keyword-hash-table* nil)
(defvar *haxe-keyword-file* "haxe")
(defvar *haxe-keyword-cap-table* nil)
(defvar *haxe-completion-list* nil)

(defvar *haxe-mode-syntax-table* nil)
(unless *haxe-mode-syntax-table*
  (setq *haxe-mode-syntax-table* (make-syntax-table))
  (do ((x #x21 (1+ x)))
      ((>= x #x7f))
    (let ((c (code-char x)))
      (unless (alphanumericp c)
    (set-syntax-punctuation *haxe-mode-syntax-table* c))))
  (set-syntax-string *haxe-mode-syntax-table* #\")
  (set-syntax-string *haxe-mode-syntax-table* #\')
  (set-syntax-symbol *haxe-mode-syntax-table* #\_)
  (set-syntax-symbol *haxe-mode-syntax-table* #\#)
  (set-syntax-match *haxe-mode-syntax-table*  #\( #\))
  (set-syntax-match *haxe-mode-syntax-table*  #\{ #\})
  (set-syntax-match *haxe-mode-syntax-table*  #\[ #\])
  (set-syntax-start-multi-comment *haxe-mode-syntax-table* "/*")
  (set-syntax-end-multi-comment *haxe-mode-syntax-table*   "*/")
  (set-syntax-start-c++-comment *haxe-mode-syntax-table*    #\/)
  (set-syntax-end-c++-comment *haxe-mode-syntax-table*   #\LFD))

(defvar *haxe-mode-abbrev-table* nil)
(unless *haxe-mode-abbrev-table*
  (define-abbrev-table '*haxe-mode-abbrev-table*))

(defun haxe-mode ()
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
  (and *haxe-keyword-file*
       (null *haxe-keyword-hash-table*)
       (setq *haxe-keyword-hash-table*
	     (load-keyword-file *haxe-keyword-file* t)))
  (when *haxe-keyword-hash-table*
    (make-local-variable 'keyword-hash-table)
    (setq keyword-hash-table *haxe-keyword-hash-table*)
    (unless *haxe-keyword-cap-table*
      (setq *haxe-keyword-cap-table* (make-hash-table :test #'equalp :size
						       (hash-table-size *haxe-keyword-hash-table*)))
      (maphash #'(lambda (key val)
		   (setf (gethash key *haxe-keyword-cap-table*) key))
	       *haxe-keyword-hash-table*)))
  (setq *local-abbrev-table* *haxe-mode-abbrev-table*)
  (setq comment-start "// ")
  (setq comment-end "")
  (setq comment-start-skip "/\\(\\*+\\|/\\)[ \t]*")
  (setq comment-indent-function 'c-comment-indent)
  (when *haxe-comment-column*
    (setq comment-column *haxe-comment-column*))
  (run-hooks '*haxe-mode-hook*))
