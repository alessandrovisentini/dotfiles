{lib, pkgs, ...}: {
  services.printing.enable = true;
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "hplip"
    ];
  # To install hp printer run: NIXPKGS_ALLOW_UNFREE=1 nix-shell -p hplipWithPlugin --run 'sudo -E hp-setup'
  services.printing.drivers = [pkgs.hplipWithPlugin];
  programs.system-config-printer.enable = true;

  # Fix for CUPS 2.4.15 GTK print dialog freeze bug
  # https://github.com/OpenPrinting/cups/issues/1429
  # Install evince from unstable (built against fixed CUPS 2.4.16)
  environment.systemPackages = let
    unstable = import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz") {
      config.allowUnfree = true;
    };
  in [
    unstable.evince
  ];
}
