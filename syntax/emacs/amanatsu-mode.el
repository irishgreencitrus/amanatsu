;;; amanatsu-mode.el --- Description -*- lexical-binding: t; -*-
;;
;; Copyright (C) 2022 irishgreencitrus
;; Author: irishgreencitrus <https://github.com/irishgreencitrus>
;; Created: March 24, 2022
;; Modified: March 24, 2022
;; Version: 0.0.1
;; Homepage: https://github.com/irishgreencitrus/amanatsu
;;
;; This file is not part of GNU Emacs.
;;
;;; Commentary:
;;
;;  Description
;;
;;; Code:
;;;
(defconst amanatsu-comment-regex
 "\\(#\\([^#]*?\\)#\\)" )
(defun amanatsu-syntax-propertize-function (start end)
  (save-excursion
    (goto-char start)
    (while (re-search-forward amanatsu-comment-regex end 'noerror)
      (let ((a (match-beginning 1))
            (b (match-end 1))
            (comment-fence (string-to-syntax "!")))
        (put-text-property a (1+ a) 'syntax-table comment-fence)
        (put-text-property (1- b) b 'syntax-table comment-fence)))))
(setq amanatsu-mode-highlights
      (let* (
             (amnt-keywords '("local" "global" "dup" "float2int" "for" "ifelse" "if" "import" "int2float" "print" "range" "require_stack" "return" "swap" "while"))
             (amnt-types '("Bool" "Int" "Float" "String" "List" "Char" "Atom" "Any" "Void"))
             (amnt-atomics ":[a-zA-Z_][a-zA-Z0-9_]*")
             (amnt-comment amanatsu-comment-regex)
             (amnt-preproc "@[a-z_]+")
             (amnt-keywords-regexp (regexp-opt amnt-keywords 'word))
             (amnt-types-regexp (regexp-opt amnt-types 'word)))
        `(
          (,amnt-comment . 'font-lock-comment-face)
          (,amnt-atomics . 'font-lock-constant-face)
          (,amnt-preproc . 'font-lock-preprocessor-face)
          (,amnt-keywords-regexp . 'font-lock-function-name-face)
          (,amnt-types-regexp . 'font-lock-type-face))))

;;;###autoload
(define-derived-mode amanatsu-mode prog-mode "Amanatsu" "A major mode for the Amanatsu programming language."
  (setq font-lock-defaults '((amanatsu-mode-highlights)))
  (setq font-lock-multiline t)
  (setq syntax-propertize-function 'amanatsu-syntax-propertize-function))
;;;###autoload
(add-to-list 'auto-mode-alist '("\\.amnt\\'" . amanatsu-mode))
(provide 'amanatsu-mode)
;;; amanatsu-mode.el ends here
