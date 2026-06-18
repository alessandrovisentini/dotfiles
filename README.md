# dotfiles

Personal configs and an installer that works on NixOS, macOS, and Fedora.

## Quick install

Run this on any supported system:

```bash
curl -fsSL https://raw.githubusercontent.com/alessandrovisentini/dotfiles/main/install.sh | bash
```

It clones the repo to `~/Development/repos/dotfiles` (installing `git` first if missing), detects the OS, and runs the matching installer.

On NixOS, finish with:

```bash
sudo nixos-rebuild switch
```

## What it does

1. **packages** — installs software
2. **symlinks** — links `config/*` into `~/.config/*`
3. **nixos** *(NixOS only)* — symlinks `nixos/*.nix` into `/etc/nixos`
4. **shell** — sources `config/shell/env.sh` from `.bashrc` / `.zshrc`
5. **post** — runs OS-specific post-install commands

Fedora and NixOS both target a Sway session; the package set is kept in sync between the two.

## Running only some steps

Each step can be run alone. Examples:

```bash
./install.sh symlinks            # only recreate ~/.config symlinks
./install.sh packages            # only install software
./install.sh symlinks post       # symlinks + post-install
./install.sh --help              # full step list
```

