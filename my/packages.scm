(define-module (my packages)
  #:use-module (gnu packages autotools)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages bison)
  #:use-module (gnu packages documentation)
  #:use-module (gnu packages freedesktop)
  #:use-module (gnu packages guile)
  #:use-module (gnu packages guile-xyz)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages man)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages python)
  #:use-module (gnu packages terminals)
  #:use-module (gnu packages texinfo)
  #:use-module (gnu packages wm)
  #:use-module (gnu packages xdisorg)
  #:use-module (gnu packages xml)
  #:use-module (gnu packages xorg)
  #:use-module (gnu packages zig)
  #:use-module (gnu packages zig-xyz)
  #:use-module (guix build-system gnu)
  #:use-module (guix build-system meson)
  #:use-module (guix build-system zig)
  #:use-module (guix git-download)
  #:use-module (guix licenses)
  #:use-module (guix packages)
  #:use-module (guix search-paths)
  #:use-module (guix gexp))

(define wlroots-X11
  (package
   (inherit wlroots)
   (name "wlroots-X11")
   (arguments
    `(#:configure-flags '("-Dbackends=['drm', 'libinput', 'x11']")))
   (propagated-inputs (modify-inputs (package-propagated-inputs wlroots)
	                             (prepend xcb-util-renderutil)))))

(define-public zig-xkbcommon-for-river-0.4
  (let ((commit "2f3ecd857bad2418cda36c56b794b5a5310391fb")
	(revision "2"))
    (package
     (name "zig-xkbcommon")
     (version (git-version "0.4.0" revision commit))
     (source (origin
	      (method git-fetch)
	      (uri (git-reference
	            (url "https://codeberg.org/ifreund/zig-xkbcommon")
	            (commit commit)))
	      (file-name (git-file-name name version))
	      (sha256
	       (base32
	        "18cjrv4gzyihs6cvr1djkb74lj76yn84p65s71ihp11fywzjc2fd"))))
     (build-system zig-build-system)
     (arguments (list #:zig zig-0.16
	              #:skip-build? #t))
     (propagated-inputs (list libxkbcommon))
     (synopsis "Zig bindings for libxkbcommon")
     (description "This package provides Zig bindings for @code{libxkbcommon}.")
     (home-page "https://codeberg.org/ifreund/zig-xkbcommon")
     (license expat))))

(define-public zig-wayland-for-river-0.4
  (let ((commit "3c6da94905ac1b27fe7792709e1b05cc55052d5a")
	(revision "1"))
    (package
     (name "zig-wayland")
     (version (git-version "0.6.0" revision commit))
     (source (origin
	      (method git-fetch)
	      (uri (git-reference
	            (url "https://codeberg.org/ifreund/zig-wayland")
	            (commit commit)))
	      (file-name (git-file-name name version))
	      (sha256
	       (base32
	        "10chjkhahkjpl9wn308qdasa955rnipsmlrzp3wryl2rv16chvyy"))))
     (build-system zig-build-system)
     (arguments
      (list #:zig zig-0.16
	    #:zig-release-type "safe"
	    #:zig-build-flags
	    #~(list "-Denable-tests")
	    #:zig-test-flags
	    #~(list "-Denable-tests")
	    #:phases
	    #~(modify-phases %standard-phases
	                     (add-after 'configure 'fix-cross-compilation
	                                (lambda _
	                                  (substitute* "build.zig"
	                                               (("pkg-config") (getenv "PKG_CONFIG"))))))))
     (propagated-inputs (list wayland wayland-protocols))
     (native-inputs (list pkg-config wayland))
     (synopsis "Zig Wayland bindings and protocol scanner")
     (description
      "This package provides Zig bindings for @code{wayland} and a @code{Scanner}
	interface.")
     (home-page "https://codeberg.org/ifreund/zig-wayland")
     (license expat))))

(define-public zig-wlroots-for-river-0.4
  (let let ((commit "7a18c03dca6afa0d80bd9e3a0619e5e5ccd18e20")
	    (revision "1"))
    (package
     (name "zig-wlroots")
     (version (git-version "0.20.1" revision commit))
     (source (origin
	      (method git-fetch)
	      (uri (git-reference
	            (url "https://codeberg.org/ifreund/zig-wlroots")
	            (commit commit)))
	      (file-name (git-file-name name version))
	      (sha256
	       (base32
	        "16cy0a65jddfhsvgvcmbj5ln7wx37nia6j6rr062k272dhkwgz3i"))))
     (build-system zig-build-system)
     (arguments
      (list #:zig zig-0.16
	    #:zig-release-type "fast"
	    #:zig-build-flags
	    #~(list "-Denable-tests")
	    #:zig-test-flags
	    #~(list "-Denable-tests")
	    #:phases
	    #~(modify-phases %standard-phases
	                     (add-after 'unpack 'prepare-build.zig.zon
	                                (lambda _
	                                  (substitute* "build.zig.zon"
	                                               (("\\.pixman") ".@\"zig-pixman\"")
	                                               (("\\.wayland") ".@\"zig-wayland\"")
	                                               (("\\.xkbcommon") ".@\"zig-xkbcommon\""))))
	                     (add-before 'build 'revert-build.zig.zon
	                                 (lambda _
	                                   (substitute* "build.zig.zon"
	                                                (("\\.@\"zig-pixman\"") ".pixman")
	                                                (("\\.@\"zig-wayland\"") ".wayland")
	                                                (("\\.@\"zig-xkbcommon\"") ".xkbcommon")))))
	    ))
     (propagated-inputs
      (list wlroots-X11
	    zig-pixman
	    zig-wayland-for-river-0.4
	    zig-xkbcommon-for-river-0.4))
     (native-inputs (list pkg-config))
     (synopsis "Zig bindings for wlroots")
     (description "This package provides Zig bindings for @code{wlroots}.")
     (home-page "https://codeberg.org/ifreund/zig-wlroots")
     (license expat))))

(define-public zig-arocc
  ;; This is on a commit that is required by zig-translate-c.
  ;; No releases as of yet.
  (let ((commit "5f5a050569a95ecc40a426f0c3666ae7ef987ede")
	(revision "0")
	(gcc-toolchain* (delay (module-ref (resolve-interface
	                                    '(gnu packages commencement))
	                                   'gcc-toolchain))))
    (package
     (name "zig-arocc")
     (version (git-version "0.0.1" revision commit))
     (source
      (origin
       (method git-fetch)
       (uri (git-reference
	     (url "https://github.com/Vexu/arocc")
	     (commit commit)))
       (file-name (git-file-name name version))
       (sha256
	(base32 "073ky6pbs9z9v0vnjs972pxvrhx5jja0g31hv6d4irdifm4p9ikz"))))
     (build-system zig-build-system)
     (arguments
      (list #:zig zig-0.16
	    #:tests? #f ;; XXX: Figure out what's wrong.
	    #:zig-build-flags
	    #~(list (string-append "-Dgcc-install-prefix=" #$(force gcc-toolchain*)))
	    #:phases
	    #~(modify-phases %standard-phases
	                     ;; (add-before 'check 'prepend-headers
	                     ;;     (lambda* _
	                     ;;       (setenv "C_INCLUDE_PATH"
	                     ;;               (string-append (getenv "TMPDIR")
	                     ;;                              "/source/out/include:"
	                     ;;                              (getenv "C_INCLUDE_PATH")))))
	                     (add-after 'install 'wrap-program
					(lambda* (#:key inputs outputs #:allow-other-keys)
					  (let* ((out (assoc-ref outputs "out"))
						 (arocc (string-append out "/bin/arocc"))
						 (wrapped-file (string-append (dirname arocc) "/." (basename arocc) "-real"))
						 (sh (search-input-file inputs "/bin/sh")))
					    (rename-file arocc wrapped-file)
					    (call-with-output-file arocc
					      (lambda (port)
						(format port
							"#!~a~%exec -a \"${0##*/}\" \"~a\" -I\"${C_INCLUDE_PATH/:/ -I}\" -L\"${LIBRARY_PATH/:/ -L}\" \"$@\"~%"
							sh
							(canonicalize-path wrapped-file))))
					    (chmod arocc #o755)))))))
     (search-paths
      (list $C_INCLUDE_PATH $LIBRARY_PATH))
     (native-search-paths search-paths)
     (inputs (list (force gcc-toolchain*)
	           bash-minimal))
     (home-page "https://github.com/Vexu/arocc")
     (synopsis "A C compiler written in Zig")
     (description "Aro is a C compiler written in Zig with a complete implementation of multiple C standards.")
     (license expat))))

(define-public zig-translate-c
  (package
   (name "zig-translate-c")
   (version "1.0.0")
   (source (origin
	    (method git-fetch)
	    (uri (git-reference
	          (url "https://codeberg.org/ziglang/translate-c")
	          (commit version)))
	    (file-name (git-file-name name version))
	    (sha256
	     (base32
	      "0hjzgskrxzqy1c3smg2iqbd7834g9s2nckzswnl4ll5qy6xpgmmm"))))
   (build-system zig-build-system)
   (arguments (list #:zig zig-0.16))
   (propagated-inputs (list zig-arocc))
   (home-page "https://codeberg.org/ziglang/translate-c")
   (synopsis "A Zig library for translating C code into Zig code")
   (description "translate-c is a Zig library maintained by Zig Software Foundation that allows to translate C code into Zig. It is intended to replace built-in implementations of this functionality.")
   (license expat)))

(define-public river-0.4
  (package
   (name "river")
   (version "0.4.7")
   (source
    (origin
     (method git-fetch)
     (uri (git-reference
	   (url "https://codeberg.org/river/river")
	   (commit (string-append "v" version))))
     (file-name (git-file-name name version))
     (sha256
      (base32 "1mq6c2ajr7dwiy4s9r8sh5b9b2q9ggj0bq4cd46131hi5j7vhfxq"))))
   (build-system zig-build-system)
   (arguments
    (list #:zig zig-0.16
	  #:install-source? #f
	  #:zig-release-type "safe"
	  #:zig-build-flags
	  #~(list "-Dpie" "-Dxwayland"
	          "--search-prefix" #$(or (this-package-input "libinput")
	                                  (this-package-input "libinput-minimal"))
	          "--search-prefix" #$(this-package-input "eudev"))
	  #:phases
	  #~(modify-phases %standard-phases
			   (add-after 'unpack 'fix-path
				      (lambda _
					(substitute* "build.zig"
						     (("/bin/sh") (which "sh")))))
			   (add-after 'unpack 'prepare-build.zig.zon
				      (lambda _
					(substitute* "build.zig.zon"
						     (("\\.pixman") ".@\"zig-pixman\"")
						     (("\\.translate_c") ".@\"zig-translate-c\"")
						     (("\\.wayland") ".@\"zig-wayland\"")
						     (("\\.wlroots") ".@\"zig-wlroots\"")
						     (("\\.xkbcommon") ".@\"zig-xkbcommon\""))))
			   (add-before 'build 'revert-build.zig.zon
				       (lambda _
					 (substitute* "build.zig.zon"
						      (("\\.@\"zig-pixman\"") ".pixman")
						      (("\\.@\"zig-translate-c\"") ".translate_c")
						      (("\\.@\"zig-wayland\"") ".wayland")
						      (("\\.@\"zig-wlroots\"") ".wlroots")
						      (("\\.@\"zig-xkbcommon\"") ".xkbcommon"))))
			   (add-after 'install 'install-wayland-session
				      (lambda _
					(let ((wayland-sessions
					       (string-append #$output "/share/wayland-sessions")))
					  (mkdir-p wayland-sessions)
					  (install-file "contrib/river.desktop"
							wayland-sessions)))))))
   (inputs
    (list libevdev
	  eudev
	  zig-translate-c
	  zig-wayland-for-river-0.4
	  zig-wlroots-for-river-0.4
	  zig-xkbcommon-for-river-0.4
	  libinput-minimal))
   (native-inputs
    (list pkg-config
	  scdoc))
   (home-page "https://isaacfreund.com/software/river/")
   (synopsis "Dynamic tiling Wayland compositor")
   (description
    "River is a dynamic tiling Wayland compositor with flexible
	runtime configuration.  It can run nested in an X11/Wayland session or also
	directly from a tty using KMS/DRM.")
   (license gpl3)))
