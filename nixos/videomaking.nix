{pkgs, ...}: let
  vars = import ./variables.nix;
in {
  users.users.${vars.mainUserName} = {
    packages = with pkgs; [
      losslesscut-bin
      ffmpeg-full
      handbrake
      makemkv
      video2x
    ];
  };
}
