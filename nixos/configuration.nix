{pkgs, ...}: {
  imports = [
    ./hardware-configuration.nix
    ./specialisation.nix
    ./system.nix
    ./hardware.nix
    ./main_user.nix
    ./display_manager.nix
    ./gnome.nix
    ./gnome-apps.nix
    ./wm-common.nix
    ./sway.nix
    ./development.nix
    ./printing.nix
    ./gaming.nix
    ./mime_apps.nix
    ./nix.nix
  ];

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;

    loader.efi.canTouchEfiVariables = true;
    loader.systemd-boot.enable = true;
    loader.systemd-boot.configurationLimit = 5;

    initrd.systemd.enable = true;

    consoleLogLevel = 0;
    kernelParams = [
      "quiet"
      "splash"
      "boot.shell_on_fail"
      "loglevel=3"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
    ];

    plymouth.enable = true; # LUKS decrypt UI
  };

  system.stateVersion = "25.11";
}
