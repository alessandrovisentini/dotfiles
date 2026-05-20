# Face unlock on hyprlock via Howdy + the IR camera (UVC interface 1.2,
# greyscale, /dev/video2 once the IPU6 is blacklisted — see hardware.nix).
#
# Howdy isn't in 25.11 (it landed in nixpkgs-unstable, so it'll be native
# in 26.05); until then the package is pinned from unstable and PAM is
# wired by hand. It's added to hyprlock ONLY, as `sufficient`: a face
# match unlocks, anything else (no match, timeout, dark room, broken
# module) falls through to the password — so this can't lock you out, and
# login/sudo are untouched.
#
# After rebuilding you must enrol a face and probably enable the IR
# illuminator — see the steps at the bottom of this file.
{
  config,
  lib,
  pkgs,
  ...
}: let
  unstable = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/d233902339c02a9c334e7e593de68855ad26c4cb.tar.gz";
    sha256 = "1485vqhb8cwym1m75v61i10j427vazszaklkwj2wmm80k8sijjyz";
  }) {inherit (pkgs) system;};

  howdy = unstable.howdy;

  # Mirrors howdy 3.0.0's shipped defaults; only no_confirmation is
  # changed (unlock as soon as the face matches, no extra keypress).
  # device_path defaults to /dev/video2, which is the IR camera here.
  howdyConfig = (pkgs.formats.ini {}).generate "howdy-config.ini" {
    core = {
      detection_notice = false;
      timeout_notice = true;
      no_confirmation = true;
      suppress_unknown = false;
      abort_if_ssh = true;
      abort_if_lid_closed = true;
      disabled = false;
      use_cnn = false;
      workaround = "off";
    };
    video = {
      certainty = "3.5";
      timeout = 4;
      device_path = "/dev/video2";
      warn_no_device = true;
      max_height = 320;
      frame_width = -1;
      frame_height = -1;
      dark_threshold = 60;
      recording_plugin = "opencv";
      device_format = "v4l2";
      force_mjpeg = false;
      exposure = -1;
      device_fps = -1;
      rotate = 0;
    };
    snapshots = {
      save_failed = false;
      save_successful = false;
    };
    rubberstamps.enabled = false;
  };
in {
  environment.systemPackages = [howdy unstable.linux-enable-ir-emitter];

  environment.etc."howdy/config.ini".source = howdyConfig;

  # Try the face first, fall back to the password. Ordered before
  # pam_unix (order 11600 in hyprlock's generated auth stack).
  security.pam.services.hyprlock.rules.auth.howdy = {
    control = "sufficient";
    modulePath = "${howdy}/lib/security/pam_howdy.so";
    order = 11500;
  };

  # Enrolment / setup (run once, after the rebuild):
  #
  #   # 1. If `sudo howdy test` shows a black/too-dark frame, enable the
  #   #    IR illuminator (device-specific, interactive):
  #   sudo linux-enable-ir-emitter configure
  #
  #   # 2. Enrol your face (do it in the lighting you'll usually unlock in):
  #   sudo howdy add
  #
  #   # 3. Lock with hyprlock and look at the camera — it should unlock.
  #
  # If the IR emitter needed `configure`, tell me and we'll add a systemd
  # service so it re-arms on every boot/resume.
}
