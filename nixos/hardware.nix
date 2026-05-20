{pkgs, ...}: {

  # Graphics
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-media-driver
    ];
  };

  # Thunderbolt
  services.hardware.bolt.enable = true;

  # Bluetooth
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings.General.Enable = "Source,Sink,Media,Socket";
  };

  # Auto Rotate Sensor
  hardware.sensor.iio.enable = true;

  # Fingerprint Scanner
  systemd.services.fprintd = {
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "simple";
  };
  services.fprintd.enable = true;

  # Camera. The integrated rear camera is an Intel IPU6 MIPI sensor
  # (ov8856) with no working soft-ISP; its driver only spawns ~60 dead
  # /dev/video ISYS nodes that hit the v4l2 monitor's device limit and
  # hide the working USB cameras. Blacklist it so WirePlumber
  # auto-detects the real (USB UVC) cameras, built-in and hot-plugged.
  boot.blacklistedKernelModules = ["intel_ipu6_isys" "intel_ipu6"];

  # With the IPU6 gone the only cameras are USB UVC, which the v4l2
  # monitor auto-detects. Disable WirePlumber's libcamera monitor so
  # each camera isn't surfaced a second time. (services.pipewire is
  # enabled in main_user.nix; this merges into it.)
  services.pipewire.wireplumber.extraConfig."52-disable-libcamera" = {
    "wireplumber.profiles".main."monitor.libcamera" = "disabled";
  };
}
