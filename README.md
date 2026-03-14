# Guix
My Guix system configuration.

```
make system
make home
make check
make fmt
make update
make installer
```

### Installation
Boot the image from `make installer`, connect to the network and run as root:
```
/etc/guix-config/scripts/bootstrap.sh <disk> <host>
```
Afterwards copy `/etc/guix-config/hosts/<host>/hardware.scm` into the repository.
