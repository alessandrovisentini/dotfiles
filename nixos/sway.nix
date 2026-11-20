{
  config,
  lib,
  pkgs,
  ...
}: let
  sessions = config.services.displayManager.sessionData.desktops;
in {
  services.greetd = {
    enable = true;
    useTextGreeter = true;
    settings.default_session.command = lib.concatStringsSep " " [
      "${pkgs.tuigreet}/bin/tuigreet"
      "--time"
      "--remember"
      "--remember-user-session"
      "--asterisks"
      "--cmd sway"
      "--env XDG_SESSION_TYPE=wayland"
      "--sessions ${sessions}/share/wayland-sessions"
    ];
  };

  # Avoid the fingerprint reader for login
  security.pam.services.greetd.fprintAuth = false;
  security.pam.services.swaylock.fprintAuth = false;

  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
    extraPackages = with pkgs; [
      # lock + idle
      swaylock
      swayidle

      # launcher
      rofi

      # bar
      waybar

      # emoji picker
      rofimoji

      # notifications
      libnotify
      swaynotificationcenter

      # brightness
      brightnessctl

      # network
      networkmanagerapplet

      # audio
      pwvucontrol
      pulseaudio # pactl

      # media keys
      playerctl

      # screenshot + color picker
      sway-contrib.grimshot
      grim
      slurp
      imagemagick_light

      # mirroring
      wl-mirror

      # icons
      adwaita-icon-theme
    ];
  };

  # File manager
  programs.thunar = {
    enable = true;
    plugins = with pkgs; [
      thunar-archive-plugin
      thunar-volman
      thunar-media-tags-plugin
    ];
  };
  programs.xfconf.enable = true;
  services.tumbler.enable = true;
  services.gvfs.enable = true;

  # Bluetooth
  services.blueman.enable = true;
  # Media keys for bluetooth headsets.
  # Not systemctl enable, on NixOS that links a store path that breaks after a GC.
  systemd.user.services.mpris-proxy.wantedBy = ["default.target"];

  # Screenshare + file pickers
  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = [pkgs.xdg-desktop-portal-gtk];
  };
}
