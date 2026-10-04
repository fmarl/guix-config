(list (channel
       (name 'guix)
       (url "https://codeberg.org/guix/guix")
       (branch "master")
       (commit "4475999050e69311f666e860ce4ea668e1299527")
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
       (commit "c869a0d33e9c42272a27ddf08cfb3780fe1c47e8"))
      (channel
       (name 'guix-microvm)
       (url "https://github.com/fmarl/guix-microvm")
       (branch "main")
       (commit "20593b1625d4b6a17dd161043b046256a6139d5d")))
