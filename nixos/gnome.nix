{
  lib,
  pkgs,
  ...
}: let
  vars = import ./variables.nix;
in {
  services.desktopManager.gnome.enable = true;

  # Make nixpkgs Electron apps (Discord, VSCode, ...) and Firefox run as
  # native Wayland clients; otherwise they go through XWayland and look
  # blurry under fractional scaling.
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
  };

  services.gnome.games.enable = false;
  services.power-profiles-daemon.enable = false; # Conflicts with autocpu-freq
  environment.gnome.excludePackages = with pkgs; [gnome-tour gnome-user-docs];

  services.gnome.gnome-browser-connector.enable = true;

  environment.systemPackages = with pkgs; [
    gnomeExtensions.appindicator
    gnomeExtensions.simple-workspaces-bar
    gnomeExtensions.disable-workspace-switcher-overlay
    (callPackage ./extensions/move-without-follow {})
  ];
  services.udev.packages = with pkgs; [gnome-settings-daemon];

  qt = {
    enable = true;
    style = "adwaita-dark";
  };

  users.users.${vars.mainUserName}.packages = with pkgs; [gnome-tweaks];

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
          # scale-monitor-framebuffer: enable fractional scaling.
          # xwayland-native-scaling: render XWayland apps at integer scale and
          # downsample, so any remaining XWayland app stays sharp.
          experimental-features = ["scale-monitor-framebuffer" "xwayland-native-scaling"];
        };
        "org/gnome/desktop/wm/preferences" = {
          num-workspaces = lib.gvariant.mkInt32 9;
        };

        # Disable conflicting Dash-to-Dock shortcuts
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

          # Super+Shift+{1..9} is handled by the move-without-follow extension
          # (sends window to workspace N without switching to it).
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

          # Cycle all windows individually (not grouped by app)
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
