{
  config,
  pkgs,
  ...
}: let
  # Exits 0 when the lid is closed
  lidClosed = pkgs.writeShellScript "lid-closed" ''
    ${pkgs.gnugrep}/bin/grep -q closed /proc/acpi/button/lid/*/state 2>/dev/null
  '';
in {
  # Graphics
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-media-driver # VA-API
      vpl-gpu-rt # Quick Sync
      intel-compute-runtime # OpenCL, for tone mapping
    ];
  };

  # Bluetooth
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings.General.Enable = "Source,Sink,Media,Socket";
  };

  # Thunderbolt
  services.hardware.bolt.enable = true;

  # Fingerprint
  services.fprintd.enable = true;

  # With the lid closed, sudo skips the fingerprint reader
  security.pam.services.sudo.rules.auth.lid-closed = {
    order = config.security.pam.services.sudo.rules.auth.fprintd.order - 1;
    # success=1 skips the next rule (the fingerprint)
    control = "[success=1 default=ignore]";
    modulePath = "${config.security.pam.package}/lib/security/pam_exec.so";
    args = ["quiet" "${lidClosed}"];
  };
}
