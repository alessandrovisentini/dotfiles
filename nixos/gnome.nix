{ lib, pkgs, ... }:
let
  vars = import ./variables.nix;
in
{
  services.xserver.desktopManager.gnome.enable = true;

  services.gnome.games.enable = false;
  services.power-profiles-daemon.enable = false; # Conflicts with autocpu-freq
  environment.gnome.excludePackages = with pkgs; [ gnome-tour gnome-user-docs ];

  qt = {
    enable = true;
    platformTheme = "gnome";
    style = "adwaita-dark";
  };

  users.users.${vars.mainUserName}.packages = with pkgs; [ gnome-tweaks ];

  programs.dconf.enable = true;
  programs.dconf.profiles.user.databases = [
    {
      lockAll = true;

      settings = {
        "org/gnome/desktop/interface" = {
          accent-color = "blue";
          enable-animations = false;
        };

        "org/gnome/desktop/input-sources" = {
          xkb-options = [ "caps:escape_shifted_capslock" "compose:ralt" ];
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
          "switch-to-workspace-1" = [ "<Super>1" ];
          "switch-to-workspace-2" = [ "<Super>2" ];
          "switch-to-workspace-3" = [ "<Super>3" ];
          "switch-to-workspace-4" = [ "<Super>4" ];
          "switch-to-workspace-5" = [ "<Super>5" ];
          "switch-to-workspace-6" = [ "<Super>6" ];
          "switch-to-workspace-7" = [ "<Super>7" ];
          "switch-to-workspace-8" = [ "<Super>8" ];
          "switch-to-workspace-9" = [ "<Super>9" ];

          "move-to-workspace-1" = [ "<Super><Shift>1" ];
          "move-to-workspace-2" = [ "<Super><Shift>2" ];
          "move-to-workspace-3" = [ "<Super><Shift>3" ];
          "move-to-workspace-4" = [ "<Super><Shift>4" ];
          "move-to-workspace-5" = [ "<Super><Shift>5" ];
          "move-to-workspace-6" = [ "<Super><Shift>6" ];
          "move-to-workspace-7" = [ "<Super><Shift>7" ];
          "move-to-workspace-8" = [ "<Super><Shift>8" ];
          "move-to-workspace-9" = [ "<Super><Shift>9" ];

          "close" = [ "<Super><Shift>q" ];
          "maximize" = [ "<Super>f" ];
          "minimize" = lib.gvariant.mkEmptyArray "s";
        };

        "org/gnome/settings-daemon/plugins/media-keys" = {
          screensaver = [ "<Super><Control>q" ];
          custom-keybindings = [ "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/" "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/" ];
        };

        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
          binding = "<Super>Return";
          command = "alacritty --option window.startup_mode='\"Maximized\"'";
          name = "Launch Alacritty Fullscreen";
        };
      };
    }
  ];
}
