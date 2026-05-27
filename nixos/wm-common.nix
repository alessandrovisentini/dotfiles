{
  config,
  lib,
  pkgs,
  ...
}: let
  dev = config.local.device;
  helpers = import ./wm-helpers.nix {inherit pkgs;};
in {
  environment.systemPackages =
    (lib.optionals dev.hasTabletMode helpers.tablet)
    ++ (lib.optionals dev.hasTouchscreen (helpers.touch ++ [pkgs.squeekboard]));

  # input for SW_TABLET_MODE; video for rotation/touch tweaks.
  users.users.${dev.userName}.extraGroups = ["input" "video"];

  # Tablet-mode detector
  systemd.user.services."mode-daemon" = lib.mkIf dev.hasTabletMode {
    description = "Tablet-mode detection daemon";
    partOf = ["graphical-session.target"];
    after = ["graphical-session.target"];
    path =
      [helpers.applyMode helpers.oskToggle helpers.gridLauncher]
      ++ (with pkgs; [coreutils systemd procps libnotify glib sway jq]);
    environment = {
      DETACHABLE_TOUCHPAD_SWAY_ID = dev.detachableTouchpadSwayId;
      DETACHABLE_KEYBOARD_HINTS = lib.concatStringsSep "|" dev.detachableKeyboardHints;
    };
    serviceConfig = {
      Type = "simple";
      ExecStart = "${helpers.modeDaemon}/bin/mode-daemon";
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
}
