Guix
====

The configuration of my Guix systems.

### Bootstrapping

Create a host with `make new-host MACHINE=<host> [OPTIONS="--no-luks"]` and
adjust its entry in `common/machines.scm`.

Build the installer with `make installer MACHINE=<host>`, boot it and run as
root:

    /etc/guix-config/scripts/bootstrap.sh [--repo URL] [<disk> [<host>]]

After the first boot, run `make post-install` as your user.
