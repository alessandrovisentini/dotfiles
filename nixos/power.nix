{
  config,
  lib,
  ...
}: let
  dev = config.local.device;
in {
  # TLP power management — opt-in per device via local.device.tlp. Single tool
  # for CPU, device runtime PM and Wi-Fi.
  config = lib.mkIf dev.tlp {
    services.power-profiles-daemon.enable = false;
    services.tlp = {
      enable = true;
      settings =
        {
          # powersave/no-turbo on battery, performance/turbo on AC.
          CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
          CPU_SCALING_GOVERNOR_ON_AC = "performance";
          CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
          CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
          CPU_BOOST_ON_BAT = 0;
          CPU_BOOST_ON_AC = 1;

          # Device runtime PM on battery (PCIe ASPM stays firmware-controlled).
          RUNTIME_PM_ON_BAT = "auto";
          RUNTIME_PM_ON_AC = "auto";

          WIFI_PWR_ON_BAT = "on";
          WIFI_PWR_ON_AC = "off";

          # Off: keep USB devices responsive, no autosuspend surprises.
          USB_AUTOSUSPEND = 0;
        }
        # ThinkPad firmware power/TDP envelope via thinkpad_acpi.
        // lib.optionalAttrs dev.isThinkpad {
          PLATFORM_PROFILE_ON_BAT = "low-power";
          PLATFORM_PROFILE_ON_AC = "balanced";
        };
    };
  };
}
