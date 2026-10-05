GUIX := guix time-machine -C channels-lock.scm --
HOSTS := $(notdir $(wildcard hosts/*))

export GUILE_LOAD_PATH := $(CURDIR)$(if $(GUILE_LOAD_PATH),:$(GUILE_LOAD_PATH))

.PHONY: all system home check fmt update installer

all: system home

system:
	sudo $(GUIX) system reconfigure system.scm

home:
	$(GUIX) home reconfigure home.scm

check:
	@for host in $(HOSTS); do \
	    if [ -f hosts/$$host/system.scm ]; then \
	        echo "== $$host: system"; \
	        $(GUIX) system build --dry-run hosts/$$host/system.scm >/dev/null || exit 1; \
	    fi; \
	    echo "== $$host: home"; \
	    $(GUIX) home build --dry-run hosts/$$host/home.scm >/dev/null || exit 1; \
	done

update:
	guix time-machine -C dotfiles/.config/guix/channels.scm -- \
	    describe -f channels > channels-lock.scm.new
	mv channels-lock.scm.new channels-lock.scm

installer:
	$(GUIX) system image -t iso9660 common/system/installer.scm

fmt:
	guix style -f $(shell git ls-files '*.scm' | grep -v '^channels-lock.scm$$')
