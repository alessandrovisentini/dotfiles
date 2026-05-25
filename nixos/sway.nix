{pkgs, ...}: let
  lisgdSway = pkgs.writeShellScriptBin "lisgd-sway" (builtins.readFile ../config/wm-scripts/lisgd-sway.sh);
  swayRotate = pkgs.writeShellScriptBin "sway-rotate" (builtins.readFile ../config/wm-scripts/sway-rotate.sh);
  swayWsShift = pkgs.writeShellScriptBin "sway-ws-shift" (builtins.readFile ../config/wm-scripts/sway-ws-shift.sh);

  # Lock wrapper: gtklock, plus gtklock-virtkb-module in tablet mode so
  # the password is typable on the touchscreen. virtkb is loaded via -m
  # at the wrapper rather than programs.gtklock.modules, so the OSK
  # only appears in tablet mode (the module always-reveals the
  # keyboard with no toggle).
  lockScreen = pkgs.writeShellScriptBin "lock-screen" (
    builtins.replaceStrings
    ["@VIRTKB@"]
    ["${pkgs.gtklock-virtkb-module}/lib/gtklock/virtkb-module.so"]
    (builtins.readFile ../config/wm-scripts/lock-screen.sh)
  );

  # ags wrapped with the libraries the bar imports; runs from source so
  # bar edits don't need a rebuild.
  agsBar = pkgs.ags.override {
    extraPackages = with pkgs; [
      astal.astal3
      astal.battery
      astal.bluetooth
      astal.network
      astal.tray
      astal.wireplumber
      astal.notifd
      astal.mpris
      astal.io
      networkmanager
    ];
  };
  astalBar = pkgs.writeShellScriptBin "astal-bar" ''
    exec ${agsBar}/bin/ags run "$HOME/.config/astal-bar/app.ts" "$@"
  '';
in {
  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
    extraPackages = with pkgs; [
      # lock + idle (gtklock from programs.gtklock below)
      swayidle
      lockScreen

      # launcher
      rofi

      # bar
      astalBar

      # touchscreen gestures + key injection
      lisgd
      wtype
      jq
      lisgdSway
      swayWsShift

      # accelerometer rotation
      swayRotate

      # notifications
      libnotify
      swaynotificationcenter

      # brightness
      brightnessctl

      # network
      networkmanagerapplet

      # audio
      pwvucontrol
      pulseaudio

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

      # apps
      nautilus
      gnome-calculator
      gnome-contacts
      gnome-font-viewer
      gnome-music
      papers
    ];
  };

  # File manager
  programs.thunar = {
    enable = true;
    plugins = with pkgs.xfce; [
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

  # Bridge Bluetooth AVRCP to MPRIS so playerctl receives headset buttons.
  systemd.user.services.mpris-proxy = {
    description = "Bluetooth MPRIS proxy";
    after = ["bluetooth.target"];
    wantedBy = ["default.target"];
    serviceConfig = {
      ExecStart = "${pkgs.bluez}/bin/mpris-proxy";
      Restart = "on-failure";
    };
  };

  # gtklock: GTK locker that can embed an OSK widget (virtkb module)
  # inside the lock window. Sway has no `abovelock` equivalent, so
  # layer-shell OSKs (squeekboard, wvkbd) can't render above
  # ext-session-lock — the locker must own the keyboard.
  programs.gtklock.enable = true;

  # Password only; fingerprint reader stays disabled at the lock.
  security.pam.services.gtklock.fprintAuth = false;

  # Screenshare + file pickers
  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = [pkgs.xdg-desktop-portal-gtk];
  };

  # Auto-rotation (started/stopped by apply-mode, tablet only)
  systemd.user.services."sway-rotate" = {
    description = "Auto-rotate the Sway panel from the accelerometer";
    partOf = ["graphical-session.target"];
    after = ["graphical-session.target"];
    path = with pkgs; [iio-sensor-proxy sway coreutils gnugrep];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${swayRotate}/bin/sway-rotate eDP-1";
      # always, not on-failure: monitor-sensor can exit cleanly when
      # iio-sensor-proxy drops its claim across suspend, ending the
      # script's read loop with exit 0 and leaving rotation dead.
      Restart = "always";
      RestartSec = 3;
    };
  };
}
