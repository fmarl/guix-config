(define-module (my linux)
  #:use-module (nongnu packages linux)
  #:use-module (gnu packages linux)
  #:use-module (guix packages)
  #:export (linux-hardened))

(define linux-hardened-config
  '("CONFIG_SECURITY_LANDLOCK=y"
    "CONFIG_LSM=\"yama,loadpin,safesetid,integrity,apparmor,smack,landlock\""
    "CONFIG_DEBUG_CREDENTIALS=y"
    "CONFIG_DEBUG_NOTIFIERS=y"
    "CONFIG_DEBUG_PI_LIST=y"
    "CONFIG_DEBUG_SG=y"
    "CONFIG_DEBUG_VIRTUAL=y"
    "CONFIG_SCHED_STACK_END_CHECK=y"
    "CONFIG_REFCOUNT_FULL=y"
    "CONFIG_RESET_ATTACK_MITIGATION=y"
    "CONFIG_LDISC_AUTOLOAD=n"
    "CONFIG_PAGE_POISONING_NO_SANITY=y"
    "CONFIG_PAGE_POISONING_ZERO=y"
    "CONFIG_INIT_ON_FREE_DEFAULT_ON=y"
    "CONFIG_ZERO_CALL_USED_REGS=y"
    "CONFIG_SECURITY_SAFESETID=y"
    "CONFIG_PANIC_TIMEOUT=-1"
    "CONFIG_GCC_PLUGINS=y"
    "CONFIG_GCC_PLUGIN_STRUCTLEAK=y"
    "CONFIG_GCC_PLUGIN_STRUCTLEAK_BYREF_ALL=y"
    "CONFIG_GCC_PLUGIN_STACKLEAK=y"
    "CONFIG_GCC_PLUGIN_RANDSTRUCT=y"
    "CONFIG_GCC_PLUGIN_RANDSTRUCT_PERFORMANCE=y"
    "CONFIG_UBSAN=y"
    "CONFIG_UBSAN_TRAP=y"
    "CONFIG_UBSAN_BOUNDS=y"
    "CONFIG_UBSAN_SANITIZE_ALL=y"
    "CONFIG_ACPI_CUSTOM_METHOD=n"
    "CONFIG_PROC_KCORE=n"
    "CONFIG_INET_DIAG=n"
    "CONFIG_CC_STACKPROTECTOR_REGULAR=n"
    "CONFIG_CC_STACKPROTECTOR_STRONG=y"
    "CONFIG_IOMMU_DEFAULT_DMA_STRICT=y"
    "CONFIG_IOMMU_DEFAULT_DMA_LAZY=n"))

(define linux-hardened
  (package
    (inherit (customize-linux
	      #:linux linux
	      #:configs linux-hardened-config))))
