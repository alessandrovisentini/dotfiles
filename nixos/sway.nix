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

      # PDF reader
      evince
    ];
  };

  programs.thunar.enable = true;
  programs.xfconf.enable = true;
  programs.thunar.plugins = with pkgs.xfce; [
    thunar-archive-plugin
    thunar-volman
  ];
  services.gvfs.enable = true;
  services.tumbler.enable = true;

  #bluetooth
  services.blueman.enable = true;

  # Fix swaylock PAM authentication when using GDM
  security.pam.services.swaylock = {
    text = ''
      auth include login
    '';
  };
}
