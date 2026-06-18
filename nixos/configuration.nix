{pkgs, ...}: {
  imports =
    [
      ./hardware-configuration.nix
      ./device.options.nix
      ./specialisation.nix
      ./base.nix
      ./hardware.nix
      ./power.nix
      ./main_user.nix
      ./apps.nix
      ./display_manager.nix
      # ./gnome.nix
      ./sway.nix
      ./tablet.nix
      ./development.nix
      ./transcription.nix
      ./printing.nix
      ./mime_apps.nix
      ./nix.nix
    ]
    # Per-machine device flags. Falls back to safe defaults from
    # device.options.nix when the file is absent
    ++ (
      if builtins.pathExists ./device.nix
      then [./device.nix]
      else []
    );

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
