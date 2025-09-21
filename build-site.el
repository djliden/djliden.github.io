;;; packages
;;;; Initialize the package system
(require 'package)
(setq package-user-dir (expand-file-name "./.packages"))
(setq package-archives '(("melpa" . "https://melpa.org/packages/")
                         ("elpa" . "https://elpa.gnu.org/packages/")))
(package-initialize)
(let ((force-refresh (getenv "ORG_SITE_REFRESH_PACKAGES")))
  (when (or force-refresh (null package-archive-contents))
    (message "Refreshing package archives%s"
             (if force-refresh " (forced)" ""))
    (condition-case err
        (package-refresh-contents)
      (error
       (message "Package refresh failed: %s" err)))))

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
(require 'json)
(require 'subr-x)

(defconst my/org-site-base-url "https://danliden.com"
  "Canonical base URL for the published site without trailing slash.")

(defconst my/org-site-root
  (file-name-directory (file-truename (or load-file-name default-directory)))
  "Root directory of the org-site repository while building.")

(defconst my/org-site-content-root
  (expand-file-name "content" my/org-site-root)
  "Absolute path to the content directory for canonical derivation.")

(defvar my/org-site--current-export-file nil
  "Holds the source Org file path during export for metadata helpers.")

(defun my/org-site--with-current-export (orig-fun filename &rest args)
  "Wrap ORIG-FUN to expose FILENAME during publishing."
  (let ((my/org-site--current-export-file filename))
    (prog1 (apply orig-fun filename args)
      (setq my/org-site--current-export-file nil))))

(defun my/org-site--escape-html (text)
  "Return TEXT with HTML entities escaped."
  (when text
    (let ((escaped (replace-regexp-in-string "&" "&amp;" text)))
      (setq escaped (replace-regexp-in-string "<" "&lt;" escaped))
      (setq escaped (replace-regexp-in-string ">" "&gt;" escaped))
      (setq escaped (replace-regexp-in-string "\"" "&quot;" escaped))
      (replace-regexp-in-string "'" "&#39;" escaped))))

(defun my/org-site--normalize-space (text)
  "Collapse whitespace inside TEXT and trim the ends."
  (when text
    (let ((collapsed (replace-regexp-in-string "[\n\r\t ]+" " " text)))
      (string-trim collapsed))))

(defun my/org-site--truncate (text &optional limit)
  "Trim TEXT to LIMIT characters (default 260) with ellipsis."
  (when text
    (let* ((limit (or limit 260))
           (trimmed (string-trim text)))
      (if (<= (length trimmed) limit)
          trimmed
        (concat (substring trimmed 0 (max 0 (- limit 3))) "...")))))

(defun my/org-site--abs-url (path)
  "Return absolute URL for PATH relative to the site base."
  (when path
    (let ((base (string-remove-suffix "/" my/org-site-base-url)))
      (cond
       ((string-match-p "\\`https?://" path) path)
       ((string-prefix-p "/" path) (concat base path))
       (t (concat base "/" path))))))

(defun my/org-site--canonical-from-file (file)
  "Compute canonical URL for FILE within the publishing project."
  (when (and file (file-exists-p file))
    (let* ((relative (file-relative-name file my/org-site-content-root))
           (outside (string-match-p "^\.\./" relative)))
      (unless outside
        (let* ((output (concat (file-name-sans-extension relative) ".html"))
               (web-path (replace-regexp-in-string "\\`\\./" "" output))
               (base (string-remove-suffix "/" my/org-site-base-url)))
          (if (string= web-path "index.html")
              base
            (concat base "/" web-path)))))))

(defun my/org-site--format-iso8601 (time)
  "Format TIME (Emacs internal time) as UTC ISO 8601 string."
  (when time
    (format-time-string "%Y-%m-%dT%H:%M:%SZ" time t)))

(defun my/org-site--collect-keyword (name)
  "Return first value for keyword NAME from current buffer."
  (let ((val (cdr (assoc-string name (org-collect-keywords (list name)) t))))
    (when val (car val))))

(defun my/org-site--insert-head-extra (lines)
  "Insert LINES (HTML strings) as #+HTML_HEAD_EXTRA entries."
  (when lines
    (save-excursion
      (goto-char (point-min))
      ;; Skip initial option lines to keep order tidy.
      (while (looking-at "^#\\+")
        (forward-line 1))
      (dolist (line lines)
        (insert (format "#+HTML_HEAD_EXTRA: %s\n" line))))))

(defun my/org-site--build-jsonld (title description canonical published modified keywords image)
  "Construct JSON-LD string for the current page."
  (let* ((base `(("@context" . "https://schema.org")
                 ("@type" . ,(if published "BlogPosting" "WebPage"))
                 ("headline" . ,title)
                 ("description" . ,description)
                 ("mainEntityOfPage" . (("@type" . "WebPage")
                                        ("@id" . ,canonical)))
                 ("author" . (("@type" . "Person")
                               ("name" . "Daniel Liden"))))))
    (setq base (if published
                   (append base `(("datePublished" . ,published)))
                 base))
    (setq base (if modified
                   (append base `(("dateModified" . ,modified)))
                 base))
    (setq base (if keywords
                   (append base `(("keywords" . ,keywords)))
                 base))
    (setq base (if image
                   (append base `(("image" . ,image)))
                 base))
    (let ((json-object-type 'alist)
          (json-array-type 'list)
          (json-key-type 'string))
      (json-encode base))))

(defun my/org-site--add-page-metadata (backend)
  "Inject SEO metadata for HTML BACKEND exports."
  (when (org-export-derived-backend-p backend 'html)
    (let* ((info (org-export-get-environment backend))
           (input (plist-get info :input-file))
           (source (or input my/org-site--current-export-file))
           (title (my/org-site--normalize-space
                   (org-element-interpret-data (plist-get info :title))))
           (desc (or (my/org-site--collect-keyword "DESCRIPTION")
                     (when source (my/org-site--normalize-space (my/get-preview source)))))
           (desc (my/org-site--truncate desc 200))
           (keywords (my/org-site--collect-keyword "KEYWORDS"))
           (image (my/org-site--collect-keyword "IMAGE"))
           (canonical (or (my/org-site--collect-keyword "CANONICAL_URL")
                          (my/org-site--canonical-from-file source)))
           (project (when source
                      (ignore-errors (org-publish-get-project-from-filename source org-publish-project-alist))))
           (date-str (my/org-site--collect-keyword "DATE"))
           (published-time (or (and date-str (ignore-errors (org-time-string-to-time date-str)))
                               (when (and project source)
                                 (ignore-errors (org-publish-find-date source project)))))
           (modified-time (when (and source (file-exists-p source))
                            (file-attribute-modification-time (file-attributes source))))
           (published-iso (my/org-site--format-iso8601 published-time))
           (modified-iso (my/org-site--format-iso8601 modified-time))
           (abs-image (my/org-site--abs-url image))
           (site-name "Daniel Liden")
           (normalized-title (or title canonical))
           (meta-lines nil))
      (setq meta-lines
            (delq nil
                  (list
                   (when canonical
                     (format "<link rel=\"canonical\" href=\"%s\">" canonical))
                   (format "<meta name=\"author\" content=\"%s\">" (my/org-site--escape-html site-name))
                   (when canonical
                     (format "<meta property=\"og:url\" content=\"%s\">" canonical))
                   (when normalized-title
                     (format "<meta property=\"og:title\" content=\"%s\">"
                             (my/org-site--escape-html normalized-title)))
                   (when desc
                     (format "<meta property=\"og:description\" content=\"%s\">"
                             (my/org-site--escape-html desc)))
                   (format "<meta property=\"og:site_name\" content=\"%s\">"
                           (my/org-site--escape-html site-name))
                   (format "<meta property=\"og:type\" content=\"%s\">"
                           (if published-iso "article" "website"))
                   (when published-iso
                     (format "<meta property=\"article:published_time\" content=\"%s\">" published-iso))
                   (when modified-iso
                     (format "<meta property=\"article:modified_time\" content=\"%s\">" modified-iso))
                   (when abs-image
                     (format "<meta property=\"og:image\" content=\"%s\">" abs-image))
                   (when abs-image
                     (format "<meta name=\"twitter:card\" content=\"summary_large_image\">"))
                   (unless abs-image
                     "<meta name=\"twitter:card\" content=\"summary\">")
                   (when normalized-title
                     (format "<meta name=\"twitter:title\" content=\"%s\">"
                             (my/org-site--escape-html normalized-title)))
                   (when desc
                     (format "<meta name=\"twitter:description\" content=\"%s\">"
                             (my/org-site--escape-html desc)))
                   (when abs-image
                     (format "<meta name=\"twitter:image\" content=\"%s\">" abs-image))
                   (when (and canonical desc normalized-title)
                     (let ((jsonld (my/org-site--build-jsonld normalized-title desc canonical
                                                             published-iso modified-iso keywords abs-image)))
                       (format "<script type=\"application/ld+json\">%s</script>" jsonld))))))
      (my/org-site--insert-head-extra meta-lines))))

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
         (let* ((full-path (concat "content/" entry))
                (preview (or (my/get-preview full-path)
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

(advice-add 'org-publish-file :around #'my/org-site--with-current-export)
(add-hook 'org-export-before-processing-hook #'my/org-site--add-page-metadata)

;;; generate site output
(org-publish-all t)

;;; build RSS feed

;;;; https://codeberg.org/SystemCrafters/systemcrafters-site/src/commit/ce3717201ab727f709f9e739842b209d10c8c51a/publish.el#L411
;;;; https://codeberg.org/SystemCrafters/systemcrafters-site/src/commit/ce3717201ab727f709f9e739842b209d10c8c51a/publish.el#L418
(defun dw/rss-extract-date (html-file)
  "Extract the post date from an HTML file, falling back gracefully if missing."
  (with-temp-buffer
    (insert-file-contents html-file)
    (let* ((dom (libxml-parse-html-region (point-min) (point-max)))
           (date-node (car (dom-by-class dom "date")))
           (date-string (when date-node (dom-text date-node))))
      (if (and date-string (not (string= "" date-string)))
          (let* ((parsed-date (parse-time-string date-string))
                 (day (nth 3 parsed-date))
                 (month (nth 4 parsed-date))
                 (year (nth 5 parsed-date)))
            ;; NOTE: Hardcoding this at 8am for now
            (encode-time 0 0 8 day month year))
        (let* ((file-attrs (file-attributes html-file))
               (mtime (and file-attrs
                           (file-attribute-modification-time file-attrs))))
          (message "RSS date fallback: using mtime for %s" html-file)
          (or mtime (current-time)))))))

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
