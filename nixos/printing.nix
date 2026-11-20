{pkgs, ...}: {
  services.printing.enable = true;
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };
  # First HP setup: NIXPKGS_ALLOW_UNFREE=1 nix-shell -p hplipWithPlugin --run 'sudo -E hp-setup'
  services.printing.drivers = [pkgs.hplipWithPlugin];
  programs.system-config-printer.enable = true;

  # Scanning (simple-scan), hplip provides the HP backend
  hardware.sane = {
    enable = true;
    extraBackends = [pkgs.hplipWithPlugin];
  };
}
