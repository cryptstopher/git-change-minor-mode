;;; git-stats-modeline.el --- Display git changes and today's commits in modeline -*- lexical-binding: t; -*-

;; Author: Chris
;; Version: 1.0.0
;; Package-Requires: ((emacs "27.1"))
;; Keywords: convenience, vc, git

;;; Commentary:

;; This minor mode displays git statistics in the modeline:
;; - Number of uncommitted changes (using built-in git diff word count)
;; - Number of commits made today
;; Format: "250/5" where 250 = changes, 5 = commits today
;;
;; The change counting is built-in and uses:
;; git diff --word-diff=porcelain HEAD | grep -e '^+[^+]' -e '^-[^-]' | wc -w
;;
;; Usage:
;;   (git-stats-modeline-mode 1)

;;; Code:

(defgroup git-stats-modeline nil
  "Display git statistics in the modeline."
  :group 'mode-line
  :prefix "git-stats-modeline-")

(defcustom git-stats-modeline-update-interval 30
  "Update interval in seconds for git statistics."
  :type 'integer
  :group 'git-stats-modeline)

(defcustom git-stats-modeline-warning-threshold 250
  "Show warning face when changes exceed this number."
  :type 'integer
  :group 'git-stats-modeline)

(defcustom git-stats-modeline-use-builtin-diff t
  "Use built-in git diff word count instead of external command.
When non-nil, counts uncommitted changes using git diff --word-diff.
When nil, uses the command specified in `git-stats-modeline-change-command'."
  :type 'boolean
  :group 'git-stats-modeline)

(defcustom git-stats-modeline-change-command "csmchange"
  "Command to run to get the number of git changes.
Only used when `git-stats-modeline-use-builtin-diff' is nil.
Should output a single number representing uncommitted changes."
  :type 'string
  :group 'git-stats-modeline)

;;; Internal variables

(defvar git-stats-modeline--change-cache nil
  "Cache for change count.")

(defvar git-stats-modeline--last-update 0
  "Timestamp of last update.")

;;; Core functions

(defun git-stats-modeline--count-word-changes ()
  "Count word-level changes in git diff using built-in logic.
Equivalent to: git diff --word-diff=porcelain HEAD | grep -e '^+[^+]' -e '^-[^-]' | wc -w"
  (let* ((default-directory (or (when buffer-file-name
                                   (file-name-directory buffer-file-name))
                                 default-directory))
         (output (shell-command-to-string
                  "git diff --word-diff=porcelain HEAD 2>/dev/null"))
         (lines (split-string output "\n" t))
         (word-count 0))
    (dolist (line lines)
      (when (or (and (string-prefix-p "+" line)
                     (not (string-prefix-p "++" line)))
                (and (string-prefix-p "-" line)
                     (not (string-prefix-p "--" line))))
        (setq word-count (1+ word-count))))
    (number-to-string word-count)))

(defun git-stats-modeline--get-changes ()
  "Return the count of git changes as a string.
Uses built-in diff logic if `git-stats-modeline-use-builtin-diff' is non-nil,
otherwise calls the command specified in `git-stats-modeline-change-command'."
  (if git-stats-modeline-use-builtin-diff
      (or (git-stats-modeline--count-word-changes) "0")
    (let ((output (shell-command-to-string
                   (format "%s 2>/dev/null" git-stats-modeline-change-command))))
      (string-trim output))))

(defun git-stats-modeline--cached-changes ()
  "Return cached change count, updating if necessary."
  (let ((now (float-time)))
    (when (or (null git-stats-modeline--change-cache)
              (> (- now git-stats-modeline--last-update)
                 git-stats-modeline-update-interval))
      (setq git-stats-modeline--change-cache (git-stats-modeline--get-changes)
            git-stats-modeline--last-update now)))
  git-stats-modeline--change-cache)

(defun git-stats-modeline--today-commits ()
  "Return the number of commits made today."
  (when buffer-file-name
    (let* ((default-directory (file-name-directory buffer-file-name))
           (count (string-trim
                   (shell-command-to-string
                    "git log --since='00:00:00' --oneline --no-merges 2>/dev/null | wc -l"))))
      (if (and count (not (string-empty-p count)))
          count
        "0"))))

(defun git-stats-modeline--format ()
  "Format the git statistics for display."
  (when (mode-line-window-selected-p)
    (let ((changes (git-stats-modeline--cached-changes))
          (commits (git-stats-modeline--today-commits)))
      (when (and changes (not (string-empty-p changes)))
        (let* ((change-count (string-to-number changes))
               (face (if (>= change-count git-stats-modeline-warning-threshold)
                        'warning
                      'font-lock-string-face)))
          (concat " "
                  (propertize changes 'face face)
                  (when commits
                    (propertize (format "/%s" commits) 'face face))))))))

;;; Modeline variable

(defvar-local git-stats-modeline-display
  '(:eval (git-stats-modeline--format))
  "Mode line construct to display git statistics.")

(put 'git-stats-modeline-display 'risky-local-variable t)

;;; Minor mode definition

;;;###autoload
(define-minor-mode git-stats-modeline-mode
  "Toggle display of git statistics in the modeline.

When enabled, shows the number of uncommitted changes and today's
commits in the format: changes/commits (e.g., \"250/5\").

The display appears in the active window only and uses a warning
face when changes exceed `git-stats-modeline-warning-threshold'."
  :global t
  :lighter nil
  :group 'git-stats-modeline
  (if git-stats-modeline-mode
      (progn
        ;; Add to mode-line-format if not already present
        (unless (member 'git-stats-modeline-display mode-line-format)
          (setq-default mode-line-format
                        (append mode-line-format '(git-stats-modeline-display))))
        (force-mode-line-update t))
    ;; Remove from mode-line-format
    (setq-default mode-line-format
                  (remove 'git-stats-modeline-display mode-line-format))
    (force-mode-line-update t)))

(provide 'git-stats-modeline)
;;; git-stats-modeline.el ends here
