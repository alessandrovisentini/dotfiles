{
  pkgs,
  lib,
  config,
  ...
}: let
  unstable = import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz") {
    config.allowUnfree = true;
  };

  whisperCppVulkan = unstable.whisper-cpp.override {vulkanSupport = true;};

  transcribe-audio = pkgs.writeShellApplication {
    name = "transcribe-audio";
    runtimeInputs = [
      pkgs.ffmpeg
      pkgs.curl
      pkgs.coreutils
      pkgs.findutils
      pkgs.gnused
      pkgs.gnutar
      pkgs.bzip2
      pkgs.python3 # inline speaker-merge step
      unstable.sherpa-onnx # speaker diarization
      whisperCppVulkan
    ];
    text = builtins.readFile ../scripts/transcribe-audio.sh;
  };
in {
  config = lib.mkIf config.local.device.hasTranscription {
    environment.systemPackages = [
      pkgs.ffmpeg
      whisperCppVulkan
      transcribe-audio
    ];
  };
}
