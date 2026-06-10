{
  config,
  lib,
  pkgs,
  ...
}: let
  dev = config.local.device;
  # Sets governor/turbo/platform_profile for the bar's performance-mode menu.
  powerProfile =
    pkgs.writeShellScriptBin "power-profile"
    (builtins.readFile ../config/wm-scripts/power-profile.sh);
in {
  config = lib.mkMerge [
    # TLP power management — opt-in per device via local.device.tlp. CPU
    # governor/turbo and platform_profile are owned by the bar's performance
    # menu (below); TLP keeps EPP, runtime PM, Wi-Fi and USB.
    (lib.mkIf dev.tlp {
      services.power-profiles-daemon.enable = false;
      services.tlp = {
        enable = true;
        settings = {
          CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
          CPU_ENERGY_PERF_POLICY_ON_AC = "performance";

          # Device runtime PM on battery (PCIe ASPM stays firmware-controlled).
          RUNTIME_PM_ON_BAT = "auto";
          RUNTIME_PM_ON_AC = "auto";

          WIFI_PWR_ON_BAT = "on";
          WIFI_PWR_ON_AC = "off";

          # Off: keep USB devices responsive, no autosuspend surprises.
          USB_AUTOSUSPEND = 0;
        };
      };
    })

    # Performance-mode knobs the bar owns (governor + turbo + platform_profile).
    # Make the sysfs files writable by the wheel group so the bar can switch
    # profiles without root, and ship the helper it calls.
    (lib.mkIf dev.isThinkpad {
      environment.systemPackages = [powerProfile];
      systemd.services."perf-profile-perms" = {
        description = "Make CPU/platform performance knobs writable by wheel";
        wantedBy = ["multi-user.target"];
        after = ["multi-user.target"];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = pkgs.writeShellScript "perf-profile-perms" ''
            set -u
            for f in \
              /sys/firmware/acpi/platform_profile \
              /sys/devices/system/cpu/intel_pstate/no_turbo \
              /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
              [ -e "$f" ] || continue
              ${pkgs.coreutils}/bin/chgrp wheel "$f" 2>/dev/null || true
              ${pkgs.coreutils}/bin/chmod g+w "$f" 2>/dev/null || true
            done
          '';
        };
      };
    })
  ];
}
