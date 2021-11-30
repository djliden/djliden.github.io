;;; packages
;;;; Initialize the package system
(require 'package)
(setq package-user-dir (expand-file-name "./.packages"))
(setq package-archives '(("melpa" . "https://melpa.org/packages/")
                         ("elpa" . "https://elpa.gnu.org/packages/")))
(package-initialize)
(unless package-archive-contents
  (package-refresh-contents))

;;;; Install dependencies
(package-install 'htmlize)

;; Load publishing system
(require 'ox-publish)


;;; Sitemap preprocessing
;;;; Get Preview

;; modify with an "if error skip" logic
(defun my/get-preview (file)
  "get preview text from a file

Uses the function here as a starting point:
https://ogbe.net/blog/blogging_with_org.html"
  (with-temp-buffer
    (insert-file-contents file)
    (goto-char (point-min))
    (let ((beg (+ 1 (re-search-forward "^#\\+BEGIN_PREVIEW$")))
          (end (progn (re-search-forward "^#\\+END_PREVIEW$")
                      (match-beginning 0))))
      (buffer-substring beg end))))


;;;; Format sitemap entries
(defun my/sitemap-entry (entry style project)
  "sitemap entry formatter

See code here for foundation:
https://loomcom.com/blog/0110_emacs_blogging_for_fun_and_profit.html"
  (when (not (directory-name-p entry)) ; when not a directory
    (format (string-join
             '("*[[file:%s][%s]]\n"
               "#+BEGIN_published\n\n"
               "%s\n"
               "#END_published\n\n"
               "%s\n"
               "----------\n"))
            entry
            (org-publish-find-title entry project)
            (format-time-string "%A, %B %_d %Y at %l:%M %p %Z" (org-publish-find-date entry project))
            (let ((preview (my/get-preview entry)))
              (insert preview)))))    
;;;; Format Sitemap
;; modify this one! (if necessary)
(defun my/org-publish-org-sitemap (title list)
  "Sitemap generation function."
  (concat "#+TITLE: Sitemap\n\n")
  (org-list-to-subtree list))

;; modify this one!
(defun my/org-publish-org-sitemap-format (entry style project)
  "Custom sitemap entry formatting: add date"
  (cond ((not (directory-name-p entry))
         (format "[[file:%s][(%s) %s]]"
                 entry
                 (format-time-string "%Y-%m-%d"
                                     (org-publish-find-date entry project))
                 (org-publish-find-title entry project)))
        ((eq style 'tree)
         ;; Return only last subdir.
         (file-name-nondirectory (directory-file-name entry)))
        (t entry)))

;;; define publishing project
(setq org-publish-project-alist
      (list
       (list "org-site:main"
             :recursive t
             :base-directory "./content"
             :publishing-directory "./public"
             :publishing-function 'org-html-publish-to-html
             :with-author nil
             :with-creator t
             :with-toc t
             :section-numbers nil
             :time-stamp-file nil
             :auto-sitemap t
             :sitemap-title nil;"Daniel Liden's Blog"
             ;:sitemap-function 'loomcom/sitemap
             :sitemap-function 'my/org-publish-org-sitemap
             :sitemap-sort-files 'anti-chronologically
             ;:sitemap-format-entry 'my/test-format
             ;:sitemap-format-entry 'my/sitemap-entry
             :sitemap-format-entry 'my/org-publish-org-sitemap-format
             :sitemap-filename "sitemap.org"
             :sitemap-style 'tree
             )))

;;; additional settings
(setq org-html-validation-link nil
      org-html-htmlize-output-type 'css)

;;; generate site output
(org-publish-all t)

(message "Build Complete!")
