{
  lib,
  pkgs,
  settings,
  ...
}: let
  unstable = import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz") {
    config.allowUnfree = true;
  };
in {
  environment.systemPackages = with pkgs; [
    # CLI utilities
    nano
    wget
    htop
    fastfetch
    wl-screenrec
    wl-clipboard
    gcc
    dig
    traceroute
    ripgrep
    fzf
    ffmpeg
    unzip
    zip

    # Development
    nodejs
    cargo
    go
    python314
    docker-compose
    delta
    jq
    gnumake
    tree-sitter
    markdownlint-cli
    alejandra
    gh
  ];

  virtualisation.docker.enable = true;
  virtualisation.podman.enable = true;

  programs.nix-ld.enable = true; # run normal linux binaries
  services.fwupd.enable = true;

  users.users.${settings.username}.packages = with pkgs; [
    alacritty

    brave-origin

    baobab # disk analyzer
    gnome-calculator
    gnome-calendar
    deja-dup
    newsflash

    pdftk
    pdfarranger
    papers # PDF reader
    simple-scan
    libreoffice
    calibre
    scribus

    geary # Emails
    protonmail-bridge
    protonmail-bridge-gui
    proton-pass

    imv
    mpv
    gimp
    inkscape-with-extensions

    tor-browser
    yt-dlp

    nethack
    lutris

    telegram-desktop
    discord
    obsidian
    unstable.claude-code
  ];

  # Browsers
  programs.firefox.enable = true;

  programs.git.enable = true;
  programs.git.lfs.enable = true;

  programs.tmux.enable = true;

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    package = unstable.neovim-unwrapped;
  };

  programs.tcpdump.enable = true;

  programs.lazygit.enable = true;

  programs.gnome-disks.enable = true;

  programs.seahorse.enable = true;

  services.deluge.enable = true;
  systemd.services.deluged.wantedBy = lib.mkForce []; # Not started at boot

  programs.localsend = {
    enable = true;
    openFirewall = true;
  };

  # AppImages
  programs.appimage.enable = true;
  programs.appimage.binfmt = true;
}
