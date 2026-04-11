{pkgs, ...}: {
  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
    extraPackages = with pkgs; [
      # locker
      swaylock

      # idle
      swayidle

      # app launcher
      rofi

      # status bar
      waybar

      # notifications
      libnotify
      dunst

      # brightness
      brightnessctl

      # network
      networkmanagerapplet

      # audio
      pwvucontrol
      pulseaudio

      # media control
      playerctl

      # screenshot
      sway-contrib.grimshot

      # color picker
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
      snapshot
      gnome-music
      papers
    ];
  };

  services.gvfs.enable = true;

  #bluetooth
  services.blueman.enable = true;

  # mpris-proxy bridges Bluetooth AVRCP controls (earphone buttons) to MPRIS D-Bus
  # so playerctl can receive play/pause/next/prev from BT headset controls
  systemd.user.services.mpris-proxy = {
    description = "Bluetooth MPRIS proxy";
    after = [ "bluetooth.target" ];
    wantedBy = [ "default.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.bluez}/bin/mpris-proxy";
      Restart = "on-failure";
    };
  };

  # Fix swaylock PAM authentication when using GDM
  security.pam.services.swaylock = {
    text = ''
      auth include login
    '';
  };
}
