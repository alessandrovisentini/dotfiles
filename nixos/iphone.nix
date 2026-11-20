{pkgs, ...}: {
  # iPhone USB
  services.usbmuxd.enable = true;

  environment.systemPackages = with pkgs; [
    libimobiledevice
  ];
}
