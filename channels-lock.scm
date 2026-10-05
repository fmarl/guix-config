(list (channel
       (name 'guix)
       (url "https://codeberg.org/guix/guix")
       (branch "master")
       (commit "4341c003d7655ac02d72aea58cda706d87d0f965")
       (introduction
        (make-channel-introduction
         "1fc71fd013a752600de04e3f5a5757fc1eafc5e7"
         (openpgp-fingerprint
          "2841 9AC6 5038 7440 C7E9  2FFA 2208 D209 58C1 DEB0"))))
      (channel
       (name 'nonguix)
       (url "https://gitlab.com/nonguix/nonguix")
       (branch "master")
       (commit "c0192e90a52cafb4d33b04734cbe9bbedd703a04")
       (introduction
        (make-channel-introduction
         "897c1a470da759236cc11798f4e0a5f7d4d59fbc"
         (openpgp-fingerprint
          "2A39 3FFF 68F4 EF7A 3D29  12AF 6F51 20A0 22FB B2D5"))))
      (channel
       (name 'sagittarius)
       (url "https://codeberg.org/fmarl/sagittarius")
       (branch "main")
       (commit "7b613a28b0d92feec0c7aae409eece6e69a9ccf5")
       (introduction
        (make-channel-introduction
         "c2302ace8d0b0d16a01668399889c9d796af5777"
         (openpgp-fingerprint
          "F2E3 8B47 808B AF7B 81D5  B27F 52C5 7B54 89B5 819D"))))
      (channel
       (name 'guix-microvm)
       (url "https://github.com/fmarl/guix-microvm")
       (branch "main")
       (commit "8d4f40beb8b468ac5551ad2fd898d2041a6a8dec")
       (introduction
        (make-channel-introduction
         "98a7990c273bae32085240cc762e6aac45e82fd9"
         (openpgp-fingerprint
          "F2E3 8B47 808B AF7B 81D5  B27F 52C5 7B54 89B5 819D")))))
