{
  config,
  lib,
  pkgs,
  ...
}: let
  dev = config.local.device;

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
    extraPackages = with pkgs;
      [
        # lock + idle (gtklock from programs.gtklock below)
        swayidle
        lockScreen

        # launcher
        rofi

        # emoji picker (floating, types into focused window)
        rofimoji

        # bar
        astalBar

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
      ];
  };

  # File manager
  # programs.thunar = {
  #   enable = true;
  #   plugins = with pkgs; [
  #     thunar-archive-plugin
  #     thunar-volman
  #     thunar-media-tags-plugin
  #   ];
  # };
  # programs.xfconf.enable = true;
  # services.tumbler.enable = true;
  # services.gvfs.enable = true;

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

  programs.gtklock.enable = true;

  # Password only; fingerprint reader stays disabled at the lock.
  security.pam.services.gtklock.fprintAuth = lib.mkIf dev.hasFingerprint false;

  # Screenshare + file pickers
  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = [pkgs.xdg-desktop-portal-gtk];
    # Without an explicit routing config, xdg-desktop-portal under
    # XDG_CURRENT_DESKTOP=sway finds no backend for FileChooser/
    # AppChooser/OpenURI: the gtk backend ships UseIn=gnome and only a
    # gnome-portals.conf exists. The result is GTK/GNOME apps (e.g.
    # deja-dup) failing with "no application to browse the folder".
    # Pin the default interfaces to gtk and keep screencast on wlr.
    config = {
      common = {
        default = ["gtk"];
        "org.freedesktop.impl.portal.Screenshot" = ["wlr"];
        "org.freedesktop.impl.portal.ScreenCast" = ["wlr"];
      };
      sway = {
        default = ["gtk"];
        "org.freedesktop.impl.portal.Screenshot" = ["wlr"];
        "org.freedesktop.impl.portal.ScreenCast" = ["wlr"];
      };
    };
  };

  # Detection runs in bash, not Nix eval: sysfs reports a page-size
  # length and `builtins.readFile` hits unexpected EOF before reading
  # the actual contents.
  system.activationScripts.swayDeviceLink = ''
    set +e
    ver="$(cat /sys/class/dmi/id/product_version 2>/dev/null)"
    case "$ver" in
        "ThinkPad X12 Detachable Gen 1") devid=x12 ;;
        "ThinkPad P14s Gen 4")           devid=p14s ;;
        *) exit 0 ;;
    esac
    repo="/home/${dev.userName}/Development/repos/dotfiles"
    [ -d "$repo/config/sway/devices" ] || exit 0
    [ -e "$repo/config/sway/devices/$devid.conf" ] || exit 0
    ${pkgs.coreutils}/bin/ln -sfn "devices/$devid.conf" "$repo/config/sway/device.conf"
    ${pkgs.coreutils}/bin/chown -h ${dev.userName}:${dev.userName} "$repo/config/sway/device.conf" 2>/dev/null || true
  '';
}
