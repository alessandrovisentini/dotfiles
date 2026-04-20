{
  lib,
  pkgs,
  config,
  ...
}: let
  home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/release-25.11.tar.gz";
  unstable = import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz") {
    config.allowUnfree = true;
  };
  configDir = builtins.dirOf (toString ./.); # Gets the directory of the .nix file
  parentDir = builtins.dirOf configDir; # Moves one level up
  vars = import ./variables.nix;
in {
  imports = [
    (import "${home-manager}/nixos")
  ];

  nixpkgs.config.allowUnfree = true;

  # User and Packages
  users.users.${vars.mainUserName} = {
    isNormalUser = true;
    uid = 1000;
    group = vars.mainUserName;
    description = vars.mainUserName;
    extraGroups = ["networkmanager" "wheel" "video" "audio" "disk" "pcap" "input"];
    packages = with pkgs; [
      alacritty
      delta
      python314
      geary
      protonmail-bridge
      protonmail-bridge-gui
      proton-pass
      tor-browser
      deja-dup
      gnome-calendar
      telegram-desktop
      pdftk
      libreoffice
      f3d
      mpv
      imv
      gnome-system-monitor
      gnome-disk-utility
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
      spotdl
      parsec-bin
      unstable.pdfarranger
      unstable.claude-code
    ];
  };
  users.groups.${vars.mainUserName} = {
    gid = 1000;
  };

  # Programs
  programs.firefox.enable = true;

  xdg.mime.enable = true;
  xdg.portal.enable = true;
  xdg.portal.wlr.enable = true;

  services.deluge.enable = true;

  programs.localsend = {
    enable = true;
    openFirewall = true;
  };

  # Spotify Firewall
  networking.firewall.allowedTCPPorts = [57621];

  # Appimages
  programs.appimage.enable = true;
  programs.appimage.binfmt = true;

  # Polkit
  security.polkit.enable = true;

  # Keyring
  services.gnome.gnome-keyring.enable = true;

  # Nerd Fonts
  fonts.packages = [
    pkgs.nerd-fonts.dejavu-sans-mono
  ];

  # Sound
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;

    extraConfig.pipewire.adjust-sample-rate = {
      "context.properties" = {
        "default.clock.rate" = 48000;
        "default.clock.min-quantum" = 256;
        "default.clock.quantum" = 512;
        "default.clock.max-quantum" = 2048;
      };
    };
  };

  # Session Variables
  environment.sessionVariables = {
    XDG_CACHE_HOME = "$HOME/.cache";
    XDG_CONFIG_HOME = "$HOME/.config";
    XDG_DATA_HOME = "$HOME/.local/share";
    XDG_STATE_HOME = "$HOME/.local/state";

    REPOS_HOME = parentDir;
    TTRPG_NOTES_HOME = "${parentDir}/ttrpg-notes";
  };

  # Aliases
  environment.shellAliases = {
    ns = "sudo nixos-rebuild switch";
    nu = "sudo nix-channel --update & sudo nixos-rebuild switch --upgrade";
    nd = "nix develop";

    t = "$REPOS_HOME/dotfiles/scripts/td.sh";
    tt = "$REPOS_HOME/dotfiles/scripts/tt.sh";

    ai = "$REPOS_HOME/dotfiles/scripts/ai/ai.sh";
    aim = "$REPOS_HOME/dotfiles/scripts/ai/ai.sh -m";
    h = "$REPOS_HOME/dotfiles/scripts/ai/h";
  };

  # Home manager
  home-manager.users.${vars.mainUserName} = {
    pkgs,
    config,
    ...
  }: {
    home.stateVersion = "25.11";

    home.username = vars.mainUserName;

    # Dark mode for GTK and QT
    dconf = {
      enable = true;
      settings."org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
        gtk-theme = "Adwaita-dark";
      };
    };

    gtk = {
      enable = true;
      theme = {
        name = "Adwaita-dark";
        package = pkgs.gnome-themes-extra;
      };
    };

    qt = {
      enable = true;
      style.name = "adwaita-dark";
    };
  };
}
