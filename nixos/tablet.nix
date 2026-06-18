# Everything for detachable/convertible tablets and touchscreens:
# mode detection, on-screen keyboard, touch gestures, auto-rotation.
# Gated by the device flags from device.options.nix.
{
  config,
  lib,
  pkgs,
  ...
}: let
  dev = config.local.device;

  modeDaemon = pkgs.writers.writePython3Bin "mode-daemon" {
    libraries = with pkgs.python3Packages; [evdev];
    doCheck = false;
  } (builtins.readFile ../config/wm-scripts/mode-daemon.py);

  applyMode = pkgs.writeShellScriptBin "apply-mode" (builtins.readFile ../config/wm-scripts/apply-mode.sh);
  oskToggle = pkgs.writeShellScriptBin "osk-toggle" (builtins.readFile ../config/wm-scripts/osk-toggle.sh);
  gridLauncher = pkgs.writeShellScriptBin "grid-toggle" (builtins.readFile ../config/wm-scripts/grid.sh);
  modeCycle = pkgs.writeShellScriptBin "mode-cycle" (builtins.readFile ../config/wm-scripts/mode-cycle.sh);
  lisgdSway = pkgs.writeShellScriptBin "lisgd-sway" (builtins.readFile ../config/wm-scripts/lisgd-sway.sh);
  swayRotate = pkgs.writeShellScriptBin "sway-rotate" (builtins.readFile ../config/wm-scripts/sway-rotate.sh);
  swayWsShift = pkgs.writeShellScriptBin "sway-ws-shift" (builtins.readFile ../config/wm-scripts/sway-ws-shift.sh);

  # GTK3, not GTK4: GTK4 layer-shell surfaces drop wl_touch events on
  # wlroots compositors.
  appGrid = pkgs.rustPlatform.buildRustPackage {
    pname = "grinch";
    version = "1.0.0";
    src = ../config/grinch;
    cargoLock.lockFile = ../config/grinch/Cargo.lock;
    nativeBuildInputs = with pkgs; [pkg-config wrapGAppsHook3];
    buildInputs = with pkgs; [
      gtk3
      gtk-layer-shell
      librsvg
      gdk-pixbuf
      glib
    ];
  };

  # Detachable convertibles (SW_TABLET_MODE switch).
  tabletPkgs = [modeDaemon applyMode modeCycle];

  # Touchscreen (OSK toggle, touch app-grid).
  touchPkgs = [oskToggle gridLauncher appGrid];

  # Touchscreen gestures + key injection, added to programs.sway.extraPackages.
  swayTouchPkgs = with pkgs; [lisgd wtype lisgdSway swayWsShift];
in {
  environment.systemPackages =
    (lib.optionals dev.hasTabletMode tabletPkgs)
    ++ (lib.optionals dev.hasTouchscreen
      (touchPkgs ++ [pkgs.squeekboard pkgs.gsettings-desktop-schemas]));

  programs.sway.extraPackages = lib.mkIf dev.hasTouchscreen swayTouchPkgs;

  # Tablet-mode detector
  systemd.user.services."mode-daemon" = lib.mkIf dev.hasTabletMode {
    description = "Tablet-mode detection daemon";
    partOf = ["graphical-session.target"];
    after = ["graphical-session.target"];
    path =
      [applyMode oskToggle gridLauncher]
      ++ (with pkgs; [coreutils systemd procps libnotify glib sway jq]);
    environment = {
      DETACHABLE_TOUCHPAD_SWAY_ID = dev.detachableTouchpadSwayId;
      DETACHABLE_KEYBOARD_HINTS = lib.concatStringsSep "|" dev.detachableKeyboardHints;
      # apply-mode toggles org.gnome.desktop.a11y.applications via gsettings;
      # since GNOME was dropped, point glib at the schema explicitly so the
      # write doesn't silently fail and the OSK auto-popup keeps working.
      GSETTINGS_SCHEMA_DIR = "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}/glib-2.0/schemas";
    };
    serviceConfig = {
      Type = "simple";
      ExecStart = "${modeDaemon}/bin/mode-daemon";
      Restart = "on-failure";
      RestartSec = 3;
    };
  };

  # On-screen keyboard. nixpkgs squeekboard ships no systemd unit and no
  # D-Bus activation file, so `exec squeekboard` from sway was the only
  # path — fragile, no restart, no way to know if it's actually up.
  systemd.user.services."squeekboard" = lib.mkIf dev.hasTouchscreen {
    description = "Squeekboard on-screen keyboard";
    partOf = ["graphical-session.target"];
    after = ["graphical-session.target"];
    wantedBy = ["graphical-session.target"];
    serviceConfig = {
      Type = "dbus";
      BusName = "sm.puri.OSK0";
      ExecStart = "${pkgs.squeekboard}/bin/squeekboard";
      Restart = "on-failure";
      RestartSec = 3;
    };
  };

  # Auto-rotation (started/stopped by apply-mode, tablet only)
  systemd.user.services."sway-rotate" = lib.mkIf dev.hasAccelerometer {
    description = "Auto-rotate the Sway panel from the accelerometer";
    partOf = ["graphical-session.target"];
    after = ["graphical-session.target"];
    path = with pkgs; [iio-sensor-proxy sway coreutils gnugrep];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${swayRotate}/bin/sway-rotate ${dev.internalOutput}";
      # always, not on-failure: monitor-sensor can exit cleanly when
      # iio-sensor-proxy drops its claim across suspend, ending the
      # script's read loop with exit 0 and leaving rotation dead.
      Restart = "always";
      RestartSec = 3;
    };
  };

  # User-level squeekboard config (OSK layout + scale).
  home-manager.users.${dev.userName} = {lib, ...}: {
    # Default OSK height is too short; bump it, more in portrait.
    dconf.settings = lib.mkIf dev.hasTouchscreen {
      "sm/puri/Squeekboard" = {
        scale-in-vertical-screen-orientation = lib.hm.gvariant.mkDouble 2.0;
        scale-in-horizontal-screen-orientation = lib.hm.gvariant.mkDouble 1.4;
      };
    };

    # Squeekboard maps content_purpose to subdirs without falling back to
    # the root layout, so the custom layout must be deployed in each subdir.
    xdg.dataFile = lib.mkIf dev.hasTouchscreen {
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
