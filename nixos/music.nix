{pkgs, ...}: let
  vars = import ./variables.nix;
in {
  users.users.${vars.mainUserName} = {
    packages = with pkgs; [
      musescore
      audacity
      transcribe
    ];
  };
}
