(list (channel
       (name 'guix)
       (url "https://codeberg.org/guix/guix")
       (branch "master")
       (commit "5c1d8cace9e8853172872f6a707a0f365374e0a8")
       (introduction
        (make-channel-introduction
         "1fc71fd013a752600de04e3f5a5757fc1eafc5e7"
         (openpgp-fingerprint
          "2841 9AC6 5038 7440 C7E9  2FFA 2208 D209 58C1 DEB0"))))
      (channel
       (name 'nonguix)
       (url "https://gitlab.com/nonguix/nonguix")
       (branch "master")
       (commit "0de6bf4b8f67297724e12d8e8b9c7532dd6d0751")
       (introduction
        (make-channel-introduction
         "897c1a470da759236cc11798f4e0a5f7d4d59fbc"
         (openpgp-fingerprint
          "2A39 3FFF 68F4 EF7A 3D29  12AF 6F51 20A0 22FB B2D5"))))
      (channel
       (name 'sagittarius)
       (url "https://codeberg.org/fmarl/sagittarius")
       (branch "main")
       (commit "5edd298e898d854c03533d19ed22cad41ffe76d3")
       (introduction
        (make-channel-introduction
         "c2302ace8d0b0d16a01668399889c9d796af5777"
         (openpgp-fingerprint
          "F2E3 8B47 808B AF7B 81D5  B27F 52C5 7B54 89B5 819D"))))
      (channel
       (name 'guix-microvm)
       (url "https://github.com/fmarl/guix-microvm")
       (branch "main")
       (commit "07819ef3b69297dbe7f37b826e1432a98b479dba")
       (introduction
        (make-channel-introduction
         "98a7990c273bae32085240cc762e6aac45e82fd9"
         (openpgp-fingerprint
          "F2E3 8B47 808B AF7B 81D5  B27F 52C5 7B54 89B5 819D")))))
