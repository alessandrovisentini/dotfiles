{
  config,
  pkgs,
  lib,
  ...
}: let
  unstable = import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz") {
    config.allowUnfree = true;
  };
  dev = config.local.device;
in {
  environment.systemPackages = with pkgs; [
    # CLI utilities
    nano
    wget
    htop
    fastfetch
    wl-screenrec
    wl-clipboard
    gcc_multi
    dig
    traceroute
    ripgrep
    fzf
    unzip

    # Development
    nodejs
    cargo
    go
    python314
    docker-compose
    delta
    glow
    jq
    gnumake
    tree-sitter
    markdownlint-cli
    android-tools
  ];

  virtualisation.docker.enable = true;

  programs.nix-ld.enable = true; # runs dynamically-linked binaries
  services.fwupd.enable = true;

  users.users.${dev.userName}.packages = with pkgs; [
    alacritty
    baobab # disk analyzer
    gnome-calculator
    gnome-calendar
    papers
    simple-scan
    geary
    protonmail-bridge
    protonmail-bridge-gui
    proton-pass
    tor-browser
    deja-dup
    telegram-desktop
    pdftk
    libreoffice
    f3d
    imv
    yt-dlp
    vlc
    calibre
    gimp
    inkscape-with-extensions
    obsidian
    ungoogled-chromium
    discord
    spotify
    easyeffects
    qpwgraph
    musescore
    audacity
    transcribe
    vscodium
    pdfarranger
    unstable.claude-code
  ];

  # Browsers
  programs.firefox = {
    enable = true;
    # text-input-v3 (OSK auto-popup) is behind a pref.
    policies.Preferences = {
      "widget.wayland-text-input-v3.enabled" = {
        Value = true;
        Status = "locked";
      };
    };
  };

  programs.git.enable = true;
  programs.git.lfs.enable = true;

  programs.tmux.enable = true;

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    # kickstart config uses vim.pack, which needs Neovim 0.12+
    package = unstable.neovim-unwrapped;
  };

  programs.tcpdump.enable = true;

  programs.lazygit.enable = true;

  programs.gnome-disks.enable = true;

  programs.seahorse.enable = true;
  services.gnome.sushi.enable = true;
  programs.steam = lib.mkIf dev.hasGaming {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
  };

  # Nautilus extension discovery
  environment.sessionVariables.NAUTILUS_4_EXTENSION_DIR = "${config.system.path}/lib/nautilus/extensions-4";
  environment.pathsToLink = ["/share/nautilus-python/extensions"];

  services.deluge.enable = true;

  programs.localsend = {
    enable = true;
    openFirewall = true;
  };

  # AppImage launcher
  programs.appimage.enable = true;
  programs.appimage.binfmt = true;

  # Spotify uses 57621 for local-network device discovery.
  networking.firewall.allowedTCPPorts = [57621];
}
