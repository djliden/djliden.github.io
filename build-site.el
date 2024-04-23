;;; packages
;;;; Initialize the package system
(require 'package)
(setq package-archives '(("melpa" . "https://melpa.org/packages/")
                         ("elpa" . "https://elpa.gnu.org/packages/")
                         ("elpa-fallback" . "https://raw.githubusercontent.com/d12frosted/elpa-mirror/master/gnu/")))
(package-initialize)
(package-refresh-contents)

;; Check and install dependencies
(dolist (package '(htmlize julia-mode ess ox-rss webfeeder esxml))
  (unless (package-installed-p package)
    (package-install package)))

(require 'julia-mode)

;; Load publishing system
(require 'ox-publish)
(require 'ox-rss)
(require 'webfeeder)
(require 'esxml)

;;; Sitemap preprocessing
;;;; Get Preview

;; modify with an "if error skip" logic
;; still need conditional
(defun my/get-preview (file)
  "get preview text from a file

Uses the function here as a starting point:
https://ogbe.net/blog/blogging_with_org.html"
  (with-temp-buffer
    (insert-file-contents file)
    (goto-char (point-min))
    (when (re-search-forward "^#\\+BEGIN_PREVIEW$" nil 1)
      (goto-char (point-min))
      (let ((beg (+ 1 (re-search-forward "^#\\+BEGIN_PREVIEW$" nil 1)))
            (end (progn (re-search-forward "^#\\+END_PREVIEW$" nil 1)
                        (match-beginning 0))))
        (buffer-substring beg end)))))

;;;; Format Sitemap
(defun my/org-publish-org-sitemap (title list)
  "Sitemap generation function."
  (concat "#+OPTIONS: toc:nil")
  (org-list-to-subtree list))

(defun my/org-publish-org-sitemap-format (entry style project)
  "Custom sitemap entry formatting: add date"
  (cond ((not (directory-name-p entry))
         (let ((preview (if (my/get-preview (concat "content/" entry))
                            (my/get-preview (concat "content/" entry))
                          "(No preview)")))
         (format "[[file:%s][(%s) %s]]\n%s"
                 entry
                 (format-time-string "%Y-%m-%d"
                                     (org-publish-find-date entry project))
                 (org-publish-find-title entry project)
                 preview)))
        ((eq style 'tree)
         ;; Return only last subdir.
         ;; ends up as a headline at higher level than the posts
         ;; it contains
         (file-name-nondirectory (directory-file-name entry)))
        (t entry)))

;;;;; Notes about Sitemap Formatting

;; (unordered ("[[file:index.org][(2021-12-01) Daniel Liden's Home Page]]") ("[[file:about.org][(2021-11-28) About Me]]") ("posts" (unordered ("[[file:posts/test1.org][(2021-11-28) Resources]]") ("[[file:posts/test2.org][(2021-11-28) Another Post]]"))))

;; this ^ is the list produced. We can see the tree structure. (unordered (posts)) at the top
;; level and then ("posts" (unordered (posts))) at the lower level.

(defun file-contents (file)
  (with-temp-buffer
    (insert-file-contents file)
    (buffer-string)))

;;; define publishing project
(setq org-publish-project-alist
      (list
       (list "org-site:main"
             :recursive t
             :base-directory "./content"
             :publishing-directory "./public"
             :publishing-function 'org-html-publish-to-html
             :html-preamble (file-contents "assets/html_preamble.html")
             :with-author nil
             :with-creator t
             :with-toc t
             :section-numbers nil
             :time-stamp-file nil
             :auto-sitemap t
             :sitemap-title nil;"Daniel Liden's Blog"
             :sitemap-format-entry 'my/org-publish-org-sitemap-format
             :sitemap-function 'my/org-publish-org-sitemap
             :sitemap-sort-files 'anti-chronologically
             :sitemap-filename "sitemap.org"
             :sitemap-style 'tree
             :html-doctype "html5"
             :html-html5-fancy t
             :htmlized-source t
             :exclude ".*/posts/drafts/.*"  ; Exclude drafts directory from publishing
             )
       (list "org-site:static"
             :base-directory "./content/"
             :base-extension "css\\|js\\|png\\|jpg\\|gif\\|pdf\\|mp3\\|ogg\\|swf\\|svg"
             :publishing-directory "./public"
             :recursive t
             :publishing-function 'org-publish-attachment
             :exclude ".*/posts/drafts/.*"  ; Exclude drafts directory from publishing
             )
       (list "org-site:assets"
             :base-directory "./assets/"
             :base-extension "css\\|js\\|png\\|jpg\\|gif\\|pdf\\|mp3\\|ogg\\|swf\\|ico"
             :publishing-directory "./public/"
             :recursive t
             :publishing-function 'org-publish-attachment)
       ))


;;; additional settings
(setq org-html-validation-link nil
      org-html-htmlize-output-type 'css
      org-html-style-default (file-contents "assets/head.html")
      org-export-use-babel nil)

;;; generate site output
(org-publish-all t)

;;; build RSS feed

;;;; https://codeberg.org/SystemCrafters/systemcrafters-site/src/commit/ce3717201ab727f709f9e739842b209d10c8c51a/publish.el#L411
;;;; https://codeberg.org/SystemCrafters/systemcrafters-site/src/commit/ce3717201ab727f709f9e739842b209d10c8c51a/publish.el#L418
(defun dw/rss-extract-date (html-file)
  "Extract the post date from an HTML file."
  (with-temp-buffer
    (insert-file-contents html-file)
    (let* ((dom (libxml-parse-html-region (point-min) (point-max)))
           (date-string (dom-text (car (dom-by-class dom "date"))))
           (parsed-date (parse-time-string date-string))
           (day (nth 3 parsed-date))
           (month (nth 4 parsed-date))
           (year (nth 5 parsed-date)))
      ;; NOTE: Hardcoding this at 8am for now
      (encode-time 0 0 8 day month year))))

;(defun dw/rss-extract-summary (html-file)
;  )

(setq webfeeder-date-function #'dw/rss-extract-date)

;;;; https://gitlab.com/ambrevar/emacs-webfeeder/-/blob/master/webfeeder.el
(webfeeder-build "rss.xml"
                 "./public"
                 "https://danliden.com"
                 (mapcar (lambda (file) (concat "posts/" file))
                         (let ((default-directory (expand-file-name "./public/posts/")))
                           (directory-files-recursively "./" ".*\\.html$")))
                 :builder 'webfeeder-make-rss
                 :title "Daniel Liden's Blog"
                 :description "Data, AI, and other writing from Daniel Liden"
                 :author "Daniel Liden")


(message "Build Complete!")
