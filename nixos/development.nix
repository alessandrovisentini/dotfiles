{pkgs, ...}: let
  vars = import ./variables.nix;
in {
  virtualisation.docker = {
    enable = true;
  };

  environment.systemPackages = with pkgs; [
    nodejs
    docker-compose
    glow
    jq
  ];

  programs.adb.enable = true;
  programs.lazygit.enable = true;

  users.users.${vars.mainUserName} = {
    packages = with pkgs; [
      vscodium
    ];
    extraGroups = [
      "adbusers"
      "docker"
    ];
  };
}
