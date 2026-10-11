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
Adjust the machine in `common/machines.scm` and the file systems in
`hosts/<host>/hardware.scm`, e.g. to `impermanent-file-systems`, then commit and
push.

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
environment.  Commit and push the generated `hosts/<host>/disk.scm`.
On hosts using `impermanent-file-systems` the repository is in
`/persist/etc/guix-config` instead.

### Impermanence
Hosts whose `hardware.scm` uses `impermanent-file-systems` have `/` on a tmpfs.
The subvolumes `@gnu`, `@persist`, `@log`, `@home` and `@boot` persist, the
directories in `%persisted-directories` are bind mounted from `/persist`,
password hashes and the store signing key are kept in `/persist/etc`.

To migrate an installed host, switch its `hardware.scm` to
`impermanent-file-systems` and run as root from the installer:
```
cryptsetup open <partition> guix-root
mkdir -p /media/home
mount -o subvol=@home /dev/mapper/guix-root /media/home
/media/home/<user>/src/guix-config/scripts/migrate-impermanence.sh <host>
```
Afterwards run `guix pull` and `make home`.
