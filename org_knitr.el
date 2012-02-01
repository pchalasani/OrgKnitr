;; Paste this file into your emacs init file: either ~/.emacs or 
;; ~/.emacs.d/yourname/my_init.el 
;; depending on your emacs is set up.


(defun ess-knitr-run-in-R (cmd &optional choose-process)
  "Convert current .org file to .Rnw, then knit it to .tex"
  "Utility function not called by user."
  (let* ((rnw-buf (current-buffer)))

    (if choose-process ;; previous behavior
    (ess-force-buffer-current "R process to load into: ")
      ;; else
      (update-ess-process-name-list)
      (cond ((= 0 (length ess-process-name-list))
         (message "no ESS processes running; starting R")
         (sit-for 1); so the user notices before the next msgs/prompt
         (R)
         (set-buffer rnw-buf)
         )
        ((not (string= "R" (ess-make-buffer-current))); e.g. Splus, need R
         (ess-force-buffer-current "R process to load into: "))
       ))

    (save-excursion
      (ess-execute (format "require(tools)")) ;; Make sure tools is loaded.
      (basic-save-buffer); do not Sweave/Stangle old version of file !
      (let* ((sprocess (get-ess-process ess-current-process-name))
         (sbuffer (process-buffer sprocess))
         (org-file (buffer-file-name))
         (rnw-file (concat
                    (file-name-sans-extension org-file)
                    ".Rnw"))
         (tex-file (concat
                    (file-name-sans-extension org-file)
                    ".tex"))
         (Rnw-dir (file-name-directory rnw-file))
	 (tex-buf (get-buffer-create " *ESS-tex-output*"))
         (pdf-status)
         (Sw-cmd
          (format
           "local({..od <- getwd(); require(knitr); setwd(%S); %s(%S); setwd(..od) })"
           Rnw-dir cmd rnw-file))
         )

    (message "converting %s to Rnw" org-file)
    (if (get-file-buffer tex-file)
        (kill-buffer (get-file-buffer tex-file)))
    (if (or (not (file-exists-p rnw-file))
            (file-newer-than-file-p org-file rnw-file))
        (progn ;; process .org --> .tex  only if needed
          (org-export-as-latex 3)
          (rename-file tex-file rnw-file t)))
    (message "%s()ing %S" cmd rnw-file)
    (ess-execute Sw-cmd 'buffer nil nil)
    (switch-to-buffer rnw-buf)
    (ess-show-buffer (buffer-name sbuffer) nil)))))

(defun ess-prompt-wait2 (proc &optional  start-of-output sleep)
  "Wait for a prompt to appear at BOL of process burffer
PROC is the ESS process. Does not change point"
;; redefined ess-prompt-wait from the ess-inf.el
  (if sleep (sleep-for sleep)); we sleep here, *and* wait below
  (if start-of-output nil (setq start-of-output (point-min)))
  (with-current-buffer (process-buffer proc)
    (while (progn
             (accept-process-output proc 0 500)
             (redisplay t)
             (goto-char (marker-position (process-mark proc)))
             (beginning-of-line)
             (if (< (point) start-of-output) (goto-char start-of-output))
             (not (looking-at inferior-ess-primary-prompt))))))



;; Convert current file's .tex version to .pdf, do NOT display!
;; modified version of ess-swv-PDF from ess-swv.el
(defun ess-tex-PDF (&optional pdflatex-cmd)
  "From LaTeX file, create a PDF (via 'texi2pdf' or 'pdflatex', ...), by
default using the first entry of `ess-swv-pdflatex-commands'"
  (interactive
   (list
    (let ((def (elt ess-swv-pdflatex-commands 0)))
      (completing-read (format "pdf latex command (%s): " def)
		       ess-swv-pdflatex-commands ; <- collection to choose from
		       nil 'confirm ; or 'confirm-after-completion
		       nil nil def))))
  (let* ((buf (buffer-name))
	 (namestem (file-name-sans-extension (buffer-file-name)))
	 (latex-filename (concat namestem ".tex"))
	 (tex-buf (get-buffer-create "*ESS-tex-output*"))
;;	 (pdfviewer (ess-get-pdf-viewer))
	 (pdf-status)
;;	 (cmdstr-win (format "start \"%s\" \"%s.pdf\""
;;			     pdfviewer namestem))
;;	 (cmdstr (format "\"%s\" \"%s.pdf\" &" pdfviewer namestem))
         )
    
    
    (message "Running '%s' on '%s' ..." pdflatex-cmd latex-filename)
    (shell-command (concat "cd " (file-name-directory latex-filename)))
    (shell-command (concat "pdflatex " latex-filename) tex-buf)
    (setq errors (org-export-latex-get-error tex-buf))
    (switch-to-buffer tex-buf)
    (if errors 
        (message (concat "** OOPS: errors in pdflatex: " errors))
      (message "Running '%s' on '%s' ... done!" pdflatex-cmd latex-filename))      

    ;; (setq pdf-status
    ;;       (call-process pdflatex-cmd nil tex-buf 1
    ;;     		  latex-filename (concat "-output-directory=" (file-name-directory latex-filename) )))
    ;; (if (not (= 0 pdf-status))
    ;;     (message "** OOPS: error in '%s' (%d)!" pdflatex-cmd pdf-status)
    ;;   (message "Running '%s' on '%s' ... done!" pdflatex-cmd latex-filename))
    (switch-to-buffer buf)

    (display-buffer tex-buf)))

(defun ess-pdflatex ()
   "Run pdflatex on current .tex file"
   (interactive)
   (ess-tex-PDF "pdflatex"))

(defun ess-knitr-weave ()
   "Run Sweave on the current .Rnw file."
   (interactive)
   (ess-knitr-run-in-R "knit")
   ;; need to wait for the prompt and refresh the emacs winds here:
   (ess-prompt-wait2 (get-process ess-current-process-name))
   (ess-tex-PDF "pdflatex"))

(global-set-key [f5] 'ess-knitr-weave) ;; .org -> .Rnw -> .tex
(global-set-key [f6] 'ess-pdflatex) ;; .tex -> .pdf
