;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2025, 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(list (channel
        (name 'guix)
        (url "https://codeberg.org/guix/guix")
        (introduction
         (make-channel-introduction "1fc71fd013a752600de04e3f5a5757fc1eafc5e7"
          (openpgp-fingerprint
           "2841 9AC6 5038 7440 C7E9  2FFA 2208 D209 58C1 DEB0"))))

      (channel
        (name 'nonguix)
        (url "https://gitlab.com/nonguix/nonguix")
        (introduction
         (make-channel-introduction "897c1a470da759236cc11798f4e0a5f7d4d59fbc"
          (openpgp-fingerprint
           "2A39 3FFF 68F4 EF7A 3D29  12AF 6F51 20A0 22FB B2D5"))))

      (channel
        (name 'sagittarius)
        (url "https://codeberg.org/fmarl/sagittarius")
        (branch "main")
        (introduction
         (make-channel-introduction "c2302ace8d0b0d16a01668399889c9d796af5777"
          (openpgp-fingerprint
           "F2E3 8B47 808B AF7B 81D5  B27F 52C5 7B54 89B5 819D"))))

      (channel
        (name 'guix-cage)
        (url "https://github.com/fmarl/guix-cage")
        (branch "main")
        (introduction
         (make-channel-introduction "56a634b5aae8a3c4e12a292ba87ac336a27ddcbc"
          (openpgp-fingerprint
           "F2E3 8B47 808B AF7B 81D5  B27F 52C5 7B54 89B5 819D"))))

      (channel
        (name 'guix-apparmor)
        (url "https://github.com/fmarl/guix-apparmor")
        (branch "main")
        (introduction
         (make-channel-introduction "2f525872b29f52123ef7c593be185c872343a38e"
          (openpgp-fingerprint
           "F2E3 8B47 808B AF7B 81D5  B27F 52C5 7B54 89B5 819D"))))

      (channel
        (name 'guix-impermanence)
        (url "https://github.com/fmarl/guix-impermanence")
        (branch "main")
        (introduction
         (make-channel-introduction "b4f6a01fe77ab0f484119b673ad105d9768a9780"
          (openpgp-fingerprint
           "F2E3 8B47 808B AF7B 81D5  B27F 52C5 7B54 89B5 819D"))))

      (channel
        (name 'guix-microvm)
        (url "https://github.com/fmarl/guix-microvm")
        (branch "main")
        (introduction
         (make-channel-introduction "98a7990c273bae32085240cc762e6aac45e82fd9"
          (openpgp-fingerprint
           "F2E3 8B47 808B AF7B 81D5  B27F 52C5 7B54 89B5 819D")))))
