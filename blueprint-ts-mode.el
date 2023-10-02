;;; blueprint-ts-mode.el --- tree-sitter support for Blueprint files  -*- lexical-binding: t; -*-

;; Copyright (C) 2023 Huan Thieu Nguyen

;; Author: Huan Thieu Nguyen <nguyenthieuhuan@gmail.com>
;; Version: 0.0.1
;; Package-Requires: ((emacs "29.1"))
;; URL: https://github.com/huanie/blueprint-ts-mode
;; Keywords: languages, blueprint, tree-sitter, gnome, gtk

;; This file is not part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Treesitter based major mode for editing Blueprint files.
;; Blueprint is a new markup language for GTK4 user interfaces.  For more information see <https://jwestman.pages.gitlab.gnome.org/blueprint-compiler/>.
;; This mode provides syntax highlighting, eglot integration and Treesitter based navigation.

;;; Code:

(require 'treesit)
(require 'rx)
(require 'eglot)

(defcustom blueprint-ts-mode-indent-offset 2
  "Number of spaces for each indentation step in `json-ts-mode'."
  :version "29.1"
  :type 'integer
  :safe 'integerp
  :group 'blueprint)

(defvar blueprint-ts-mode--keywords
  '("menu" "item" "section" "styles" "using" "bind" "template")
  "Blueprint keywords for tree-sitter font-locking.")

(defmacro blueprint-ts-mode--treesit-font-lock-rules (language &rest rules)
  "Wrapper around `treesit-font-lock-rules'.
`LANGUAGE' is the treesitter language to use.
`RULES' are the features and the match pattern."
  `(treesit-font-lock-rules ,@(seq-reduce
			       (lambda (accum element)
				 (if (eq :feature element)
				     (append accum `(:language ,language ,element))
				   (append accum `(,element))))
			       rules '())))

(defvar blueprint-ts-mode--indent-rules
  `((blueprint
     ((node-is "}") parent-bol 0)
     ((node-is ")") parent-bol 0)
     ((node-is "]") parent-bol 0)
     ((n-p-gp "object" "child" "object_content")
      prev-sibling 0) ;; [child_type] indent
     ((parent-is "object_content") parent-bol blueprint-ts-mode-indent-offset)
     ((parent-is "template") parent-bol blueprint-ts-mode-indent-offset)
     ((parent-is "styles") parent-bol blueprint-ts-mode-indent-offset)
     ((parent-is "menu") parent-bol blueprint-ts-mode-indent-offset)
     ((parent-is "menu_child") parent-bol blueprint-ts-mode-indent-offset)
     ((parent-is "child") no-indent blueprint-ts-mode-indent-offset))))

(defvar blueprint-ts-mode--tresit-font-lock-setting
  (blueprint-ts-mode--treesit-font-lock-rules
   'blueprint
   :feature 'variable
   '([(object _ id: (_) @font-lock-variable-name-face)
      (menu "menu" id: (_) @font-lock-variable-name-face)])
   :feature 'comment
   '((comment) @font-lock-comment-face)
   :feature 'keyword
   `([,@blueprint-ts-mode--keywords] @font-lock-keyword-face)
   :feature 'number
   '([(number_literal _) (version)] @font-lock-number-face)
   :feature 'string
   '([(quoted)] @font-lock-string-face)
   :feature 'bracket
   :override t
   '(["[" "]" "{" "}" "(" ")"] @font-lock-bracket-face)
   :feature 'property-name
   '([(property name: (_) @font-lock-property-name-face)
      (menu_attribute name: (_) @font-lock-property-name-face)])
   :feature 'property-use
   '([(child_type)] @font-lock-property-use-face)
   :feature 'type
   '([(using _ namespace: (_) @font-lock-type-face)
      (type_name) (expression)]
     @font-lock-type-face))
  "Treesitter font-lock settings.")

;;;###autoload
(define-derived-mode blueprint-ts-mode prog-mode "Blueprint"
  "Blueprint major mode using treesitter."
  :group 'blueprint
  (when (treesit-ready-p 'blueprint)
    (treesit-parser-create 'blueprint)
    ;; Comments
    (setq-local comment-start "// ")
    (setq-local comment-start-skip "\\(?://+\\|/\\*+\\)\\s *")
    (setq-local comment-end "")
    ;; Electric
    (setq-local electric-indent-chars
		(append "{}():;,[]" electric-indent-chars))
    ;; Indent
    (setq-local treesit-simple-indent-rules blueprint-ts-mode--indent-rules)
    ;; Navigation
    (setq-local treesit-defun-type-regexp
		(rx (or "template" "object" "menu")))
    (setq-local treesit-sentence-type-regexp (rx (or "menu_attribute" "property")))
    ;; Font-lock
    (setq-local treesit-font-lock-level 4)
    (setq-local treesit-font-lock-feature-list
		'((comment variable)
		  (string keyword type)
		  (property-name property-use variable)
		  (bracket delimiter)))
    (setq-local treesit-font-lock-settings blueprint-ts-mode--tresit-font-lock-setting)
    (treesit-major-mode-setup)))

(add-to-list 'auto-mode-alist '("\\.blp\\'" . blueprint-ts-mode))
(add-to-list 'eglot-server-programs
             '(blueprint-ts-mode . ("blueprint-compiler" "lsp")))


(provide 'blueprint-ts-mode)
;;; blueprint-ts-mode.el ends here
