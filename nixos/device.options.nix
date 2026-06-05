{lib, ...}: {
  options.local.device = {
    hasTabletMode = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Detachable/convertible with a SW_TABLET_MODE switch. Enables the tablet-mode daemon and apply-mode wrapper.";
    };
    hasTouchscreen = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Built-in touchscreen. Enables squeekboard (OSK), lisgd gestures, and the grinch touch app grid.";
    };
    hasAccelerometer = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Has an iio accelerometer. Enables iio-sensor-proxy and the sway-rotate service.";
    };
    hasFingerprint = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Has a fingerprint reader. Enables fprintd.";
    };
    hasIpu6Camera = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Has an Intel IPU6 MIPI camera. Blacklists the broken ISP modules and disables the libcamera monitor.";
    };
    hasThunderbolt = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Has a Thunderbolt controller. Enables bolt.";
    };
    hasGaming = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enables gaming software (Steam with Remote Play and dedicated server firewall openings).";
    };
    internalOutput = lib.mkOption {
      type = lib.types.str;
      default = "eDP-1";
      description = "Internal panel output name in Sway.";
    };
    userName = lib.mkOption {
      type = lib.types.str;
      default = "nixos";
      description = "Primary user account name. Owns the UID 1000 user and the home-manager profile.";
    };
    hostName = lib.mkOption {
      type = lib.types.str;
      default = "nixos";
      description = "Networking hostname.";
    };
    detachableTouchpadSwayId = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Sway input identifier for the detachable keyboard's touchpad, disabled by apply-mode when the keyboard is removed. Empty disables the toggle.";
    };
    detachableKeyboardHints = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Substrings matched against /proc/bus/input/devices by mode-daemon to detect whether the detachable keyboard is attached.";
    };
  };
}
