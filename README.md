For educational purposes, this Emacs Lisp program provides an approach or a way you can visualize unstaged git changes in your Emacs modline.

## Basic usage and configurations

Load the file:

`(load-file "/path/to/git-stats-modeline.el")`

Enable the mode (uses built-in change counting by default):

`(git-stats-modeline-mode 1)`

Optionally customize settings:

`(setq git-stats-modeline-warning-threshold 300)`
`(setq git-stats-modeline-update-interval 60)`

Optionally use external command instead of built-in counting:

`(setq git-stats-modeline-use-builtin-diff nil)`
`(setq git-stats-modeline-change-command "csmchange")`
