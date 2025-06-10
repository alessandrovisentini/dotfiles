{pkgs, ...}: let
  vars = import ./variables.nix;
in {
  # Enable Flakes (for .flake files)
  nix.settings.experimental-features = ["nix-command" "flakes"];

  environment.systemPackages = with pkgs; [
    nodejs
  ];

  programs.adb.enable = true;
  programs.lazygit.enable = true;

  users.users.${vars.mainUserName} = {
    packages = with pkgs; [
      vscodium
    ];
    extraGroups = [
      "adbusers"
    ];
  };
}
