# dotfiles

Configs for Linux and macOS.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/alessandrovisentini/dotfiles/main/install.sh | bash
```

or from a clone:

```bash
git clone https://github.com/alessandrovisentini/dotfiles.git ~/Development/repos/dotfiles
~/Development/repos/dotfiles/install.sh
```

`install.sh` is safe to re-run. It:

- if not run from a checkout, clones the repo to `~/Development/repos/dotfiles` over https (through `nix-shell -p git` on a fresh NixOS)
- sources `config/shell/*.sh` from `~/.bashrc` and `~/.profile`
- symlinks configs into `~/.config` (the sway ones only if sway is installed)
- moves real files that are in the way to `<name>.backup.<date>`
- on NixOS only: links `/etc/nixos/configuration.nix` to `nixos/configuration.nix` and runs `sudo nixos-rebuild switch`
