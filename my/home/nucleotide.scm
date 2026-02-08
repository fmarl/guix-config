(define-module (my home nucleotide)
  #:use-module (gnu packages)
  #:export (%nucleotide-packages))

(define %nucleotide-packages
  (specifications->packages
   (list
    "imv"
    "zathura"
    "mpv"
    "bemenu")))
