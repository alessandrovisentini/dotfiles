{pkgs, ...}: let
  vars = import ./variables.nix;
  helpers = import ./wm-helpers.nix {inherit pkgs;};
in {
  environment.systemPackages =
    helpers.all
    ++ (with pkgs; [squeekboard]);

  # input for SW_TABLET_MODE; video for rotation/touch tweaks.
  users.users.${vars.mainUserName}.extraGroups = ["input" "video"];

  # Tablet-mode detector
  systemd.user.services."mode-daemon" = {
    description = "ThinkPad X12 tablet-mode detection daemon";
    partOf = ["graphical-session.target"];
    after = ["graphical-session.target"];
    path =
      [helpers.applyMode helpers.oskToggle helpers.gridLauncher]
      ++ (with pkgs; [coreutils systemd procps libnotify glib sway jq]);
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
  systemd.user.services."squeekboard" = {
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
