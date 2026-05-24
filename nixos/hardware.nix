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

  # Accelerometer
  hardware.sensor.iio.enable = true;

  # Fingerprint
  systemd.services.fprintd = {
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "simple";
  };
  services.fprintd.enable = true;

  # Camera: IPU6 has no working soft-ISP and spawns ~60 dead /dev/video nodes
  # that exhaust the v4l2 device limit and hide the USB cameras.
  boot.blacklistedKernelModules = ["intel_ipu6_isys" "intel_ipu6"];

  # Disable libcamera monitor so USB UVC cameras aren't enumerated twice.
  services.pipewire.wireplumber.extraConfig."52-disable-libcamera" = {
    "wireplumber.profiles".main."monitor.libcamera" = "disabled";
  };
}
