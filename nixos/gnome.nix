{
  config,
  lib,
  pkgs,
  ...
}: {
  services.desktopManager.gnome.enable = true;

  services.gnome.games.enable = false;
  services.gnome.core-apps.enable = false;
  services.power-profiles-daemon.enable = false; # conflicts with TLP
  environment.gnome.excludePackages = with pkgs; [gnome-tour gnome-user-docs];
  users.users.${config.local.device.userName}.packages = with pkgs; [gnome-tweaks];

  services.gnome.gnome-browser-connector.enable = true;
  environment.systemPackages = with pkgs; [
    gnomeExtensions.appindicator
    gnomeExtensions.simple-workspaces-bar
    gnomeExtensions.disable-workspace-switcher-overlay
    (callPackage ./extensions/move-without-follow {})
  ];

  services.udev.packages = with pkgs; [gnome-settings-daemon];
  programs.dconf.enable = true;
  programs.dconf.profiles.user.databases = [
    {
      lockAll = true;

      settings = {
        "org/gnome/shell" = {
          enabled-extensions = [
            "appindicatorsupport@rgcjonas.gmail.com"
            "move-without-follow@local"
            "simple-workspaces-bar@null-git"
            "disable-workspace-switcher-overlay@cleardevice"
          ];
        };

        "org/gnome/desktop/interface" = {
          accent-color = "blue";
          enable-animations = false;
          enable-hot-corners = false;
        };

        "org/gnome/desktop/background" = {
          picture-uri = "";
          picture-uri-dark = "";
          picture-options = "none";
          primary-color = "#000000";
          color-shading-type = "solid";
        };

        "org/gnome/desktop/input-sources" = {
          xkb-options = ["caps:escape_shifted_capslock" "compose:ralt"];
        };

        "org/gnome/shell/window-switcher" = {
          current-workspace-only = true;
        };
        "org/gnome/shell/app-switcher" = {
          current-workspace-only = true;
        };

        "org/gnome/desktop/peripherals/touchpad" = {
          tap-to-click = false;
        };

        "org/gnome/mutter" = {
          dynamic-workspaces = false;
          # Fractional scaling + downsample XWayland to keep it sharp.
          experimental-features = ["scale-monitor-framebuffer" "xwayland-native-scaling"];
        };
        "org/gnome/desktop/wm/preferences" = {
          num-workspaces = lib.gvariant.mkInt32 9;
        };

        "org/gnome/shell/keybindings" = {
          "switch-to-application-1" = lib.gvariant.mkEmptyArray "s";
          "switch-to-application-2" = lib.gvariant.mkEmptyArray "s";
          "switch-to-application-3" = lib.gvariant.mkEmptyArray "s";
          "switch-to-application-4" = lib.gvariant.mkEmptyArray "s";
          "switch-to-application-5" = lib.gvariant.mkEmptyArray "s";
          "switch-to-application-6" = lib.gvariant.mkEmptyArray "s";
          "switch-to-application-7" = lib.gvariant.mkEmptyArray "s";
          "switch-to-application-8" = lib.gvariant.mkEmptyArray "s";
          "switch-to-application-9" = lib.gvariant.mkEmptyArray "s";
        };

        "org/gnome/mutter" = {
          overlay-key = "";
        };

        "org/gnome/shell/keybindings" = {
          toggle-overview = ["<Super>d"];
        };

        "org/gnome/desktop/wm/keybindings" = {
          "switch-to-workspace-1" = ["<Super>1"];
          "switch-to-workspace-2" = ["<Super>2"];
          "switch-to-workspace-3" = ["<Super>3"];
          "switch-to-workspace-4" = ["<Super>4"];
          "switch-to-workspace-5" = ["<Super>5"];
          "switch-to-workspace-6" = ["<Super>6"];
          "switch-to-workspace-7" = ["<Super>7"];
          "switch-to-workspace-8" = ["<Super>8"];
          "switch-to-workspace-9" = ["<Super>9"];

          # Super+Shift+{1..9} handled by move-without-follow extension.
          "move-to-workspace-1" = lib.gvariant.mkEmptyArray "s";
          "move-to-workspace-2" = lib.gvariant.mkEmptyArray "s";
          "move-to-workspace-3" = lib.gvariant.mkEmptyArray "s";
          "move-to-workspace-4" = lib.gvariant.mkEmptyArray "s";
          "move-to-workspace-5" = lib.gvariant.mkEmptyArray "s";
          "move-to-workspace-6" = lib.gvariant.mkEmptyArray "s";
          "move-to-workspace-7" = lib.gvariant.mkEmptyArray "s";
          "move-to-workspace-8" = lib.gvariant.mkEmptyArray "s";
          "move-to-workspace-9" = lib.gvariant.mkEmptyArray "s";

          "close" = ["<Super><Shift>q"];
          "maximize" = ["<Super>f"];
          "minimize" = lib.gvariant.mkEmptyArray "s";

          # Cycle windows individually, not grouped by app.
          "switch-windows" = ["<Super>Tab"];
          "switch-windows-backward" = ["<Super><Shift>Tab"];
          "switch-applications" = lib.gvariant.mkEmptyArray "s";
          "switch-applications-backward" = lib.gvariant.mkEmptyArray "s";
        };

        "org/gnome/settings-daemon/plugins/media-keys" = {
          screensaver = ["<Super><Control>q"];
          custom-keybindings = ["/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/" "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"];
        };

        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
          binding = "<Super>Return";
          command = "alacritty --option window.startup_mode='\"Maximized\"'";
          name = "Launch Alacritty Fullscreen";
        };

        "org/gnome/settings-daemon/plugins/power" = {
          sleep-inactive-ac-type = "nothing";
          sleep-inactive-battery-type = "nothing";
        };
      };
    }
  ];
}
