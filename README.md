# Guix
The configuration of my Guix systems.

```
common/
  system/   shared operating-system parts, %base-os in base.scm
  home/     home services, base-home-environment in base.scm
  lib.scm machines.scm users.scm
hosts/<host>/
  system.scm   (operating-system (inherit %base-os) ...)
  home.scm     (base-home-environment '<host> ...)
dotfiles/      files deployed as-is
```

`system.scm` and `home.scm` pick the host by hostname, falling back to
`hosts/default`.  The channels are pinned in `channels-lock.scm`.

```
guix shell        # or direnv, provides make
make system       # reconfigure the system
make home         # reconfigure the home environment
make check        # evaluate all hosts
make fmt          # format with guix style
make update       # update channels-lock.scm
make installer    # build an installer image
```

### Installation
Boot the image from `make installer`, then:
```
cp -rT /etc/guix-config ~/guix-config && chmod -R u+w ~/guix-config
sudo ~/guix-config/scripts/bootstrap.sh <disk> <host>
```
