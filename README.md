# Guix
My Guix system configuration.

```
make system
make home
make check
make fmt
make update
make installer MACHINE=<host>|generic
make new-host MACHINE=<host>
make post-install
```

### New host
```
make new-host MACHINE=<host>
```
Adjust the machine in `common/machines.scm`, then commit and push.

### Installation
Build the image with `make installer MACHINE=<host>`, which already contains
the kernel of that host, or `MACHINE=generic` for the standard kernel. Boot it,
connect to the network and run as root:
```
/etc/guix-config/scripts/bootstrap.sh [--repo <url>] [<disk> [<host>]]
```
After the first login run in `/etc/guix-config`:
```
guix shell -m manifest.scm -- make post-install
```
It moves the repository to `~/src/guix-config` and reconfigures the home
environment.  Commit and push the generated `hosts/<host>/hardware.scm`.
