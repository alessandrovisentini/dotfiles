{
  config,
  lib,
  pkgs,
  ...
}: let
  dev = config.local.device;
in {
  # Graphics
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-media-driver
    ];
  };

  # Bluetooth
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings.General.Enable = "Source,Sink,Media,Socket";
  };

  # Battery/power over D-Bus (was implicit via GNOME); AstalBattery needs it.
  services.upower.enable = true;

  # Thunderbolt
  services.hardware.bolt.enable = lib.mkIf dev.hasThunderbolt true;

  # Accelerometer
  hardware.sensor.iio.enable = lib.mkIf dev.hasAccelerometer true;

  # Fingerprint
  systemd.services.fprintd = lib.mkIf dev.hasFingerprint {
    wantedBy = ["multi-user.target"];
    serviceConfig.Type = "simple";
  };
  services.fprintd.enable = lib.mkIf dev.hasFingerprint true;

  # Camera: IPU6 has no working soft-ISP and spawns ~60 dead /dev/video nodes
  # that exhaust the v4l2 device limit and hide the USB cameras.
  boot.blacklistedKernelModules = lib.mkIf dev.hasIpu6Camera ["intel_ipu6_isys" "intel_ipu6"];

  # Disable libcamera monitor so USB UVC cameras aren't enumerated twice.
  services.pipewire.wireplumber.extraConfig = lib.mkIf dev.hasIpu6Camera {
    "52-disable-libcamera" = {
      "wireplumber.profiles".main."monitor.libcamera" = "disabled";
    };
  };
}
