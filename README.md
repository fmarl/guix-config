# Guix
My Guix system configuration.

```
make system
make home
make check
make fmt
make update
make installer MACHINE=<host>|generic
```

### Installation
Build the image with `make installer MACHINE=<host>`, which already contains
the kernel of that host, or `MACHINE=generic` for the standard kernel. Boot it,
connect to the network and run as root:
```
/etc/guix-config/scripts/bootstrap.sh <disk> <host>
```
Afterwards copy `/etc/guix-config/hosts/<host>/hardware.scm` into the repository.
