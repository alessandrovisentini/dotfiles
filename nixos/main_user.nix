{
  lib,
  pkgs,
  config,
  ...
}: let
  home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/release-26.05.tar.gz";
  configDir = builtins.dirOf (toString ./.);
  parentDir = builtins.dirOf configDir;
  dev = config.local.device;
  outerCfg = config;
in {
  imports = [
    (import "${home-manager}/nixos")
  ];

  nixpkgs.config.allowUnfree = true;

  # User and group (app packages live in apps.nix)
  users.users.${dev.userName} = {
    isNormalUser = true;
    uid = 1000;
    group = dev.userName;
    description = dev.userName;
    extraGroups = ["networkmanager" "wheel" "video" "audio" "disk" "pcap" "input"];
  };
  users.groups.${dev.userName} = {
    gid = 1000;
  };

  xdg.mime.enable = true;
  xdg.portal.enable = true;
  xdg.portal.wlr.enable = true;

  # Polkit
  security.polkit.enable = true;

  # dconf GSettings backend (was implicit via GNOME); home-manager dconf needs it.
  programs.dconf.enable = true;

  # Keyring
  services.gnome.gnome-keyring.enable = true;

  # Fonts
  fonts.packages = with pkgs; [
    nerd-fonts.dejavu-sans-mono
    adwaita-fonts
  ];

  # System-wide Qt platform theme (user-level qt5ct/qt6ct config lives
  # in the home-manager block below).
  qt = {
    enable = true;
    style = "adwaita-dark";
  };

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

  # Session variables
  environment.sessionVariables = {
    XDG_CACHE_HOME = "$HOME/.cache";
    XDG_CONFIG_HOME = "$HOME/.config";
    XDG_DATA_HOME = "$HOME/.local/share";
    XDG_STATE_HOME = "$HOME/.local/state";

    REPOS_HOME = parentDir;
    TTRPG_NOTES_HOME = "${parentDir}/ttrpg-notes";

    # Native Wayland for Electron + Firefox; XWayland is blurry under
    # fractional scaling.
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
  };

  # Aliases
  environment.shellAliases = {
    ns = "sudo nixos-rebuild switch";
    nu = "sudo nix-channel --update & sudo nixos-rebuild switch --upgrade";
    nd = "nix develop";

    t = "$REPOS_HOME/dotfiles/scripts/td.sh";
    tt = "$REPOS_HOME/dotfiles/scripts/tt.sh";

    ai = "$REPOS_HOME/dotfiles/scripts/ai/ai.sh";
    h = "$REPOS_HOME/dotfiles/scripts/ai/h.sh";
  };

  # Home Manager
  home-manager.users.${dev.userName} = {
    lib,
    pkgs,
    config,
    ...
  }: let
    dev = outerCfg.local.device;
  in {
    home.stateVersion = "25.11";

    home.username = dev.userName;

    dconf = {
      enable = true;
      settings =
        {
          "org/gnome/desktop/interface" = {
            color-scheme = "prefer-dark";
            gtk-theme = "Adwaita-dark";
            cursor-theme = "Adwaita";
          };
          "org/gnome/nm-applet" = {
            disable-connected-notifications = true;
            disable-disconnected-notifications = true;
            disable-vpn-notifications = true;
            suppress-wireless-networks-available = true;
          };
        }
        # Default OSK height is too short; bump it, more in portrait.
        // lib.optionalAttrs dev.hasTouchscreen {
          "sm/puri/Squeekboard" = {
            scale-in-vertical-screen-orientation =
              lib.hm.gvariant.mkDouble 2.0;
            scale-in-horizontal-screen-orientation =
              lib.hm.gvariant.mkDouble 1.4;
          };
        };
    };

    gtk = {
      enable = true;
      theme = {
        name = "Adwaita-dark";
        package = pkgs.gnome-themes-extra;
      };

      gtk4.theme = {
        name = "Adwaita-dark";
        package = pkgs.gnome-themes-extra;
      };
    };

    qt = {
      enable = true;
      style.name = "adwaita-dark";
    };

    # Squeekboard maps content_purpose to subdirs without falling back to
    # the root layout, so the custom layout must be deployed in each subdir.
    xdg.dataFile = lib.optionalAttrs dev.hasTouchscreen {
      "squeekboard/keyboards/us.yaml".source =
        ../config/squeekboard/us.yaml;
      "squeekboard/keyboards/us_wide.yaml".source =
        ../config/squeekboard/us_wide.yaml;
      "squeekboard/keyboards/url/us.yaml".source =
        ../config/squeekboard/us.yaml;
      "squeekboard/keyboards/url/us_wide.yaml".source =
        ../config/squeekboard/us_wide.yaml;
      "squeekboard/keyboards/email/us.yaml".source =
        ../config/squeekboard/us.yaml;
      "squeekboard/keyboards/email/us_wide.yaml".source =
        ../config/squeekboard/us_wide.yaml;
      "squeekboard/keyboards/terminal/us.yaml".source =
        ../config/squeekboard/us.yaml;
      "squeekboard/keyboards/terminal/us_wide.yaml".source =
        ../config/squeekboard/us_wide.yaml;
    };
  };
}
