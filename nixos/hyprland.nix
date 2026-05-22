{
  pkgs,
  ...
}: let
  vars = import ./variables.nix;

  modeDaemon = pkgs.writers.writePython3Bin "mode-daemon" {
    libraries = with pkgs.python3Packages; [evdev];
    doCheck = false;
  } (builtins.readFile ../config/wm-scripts/mode-daemon.py);

  applyMode = pkgs.writeShellScriptBin "apply-mode" (builtins.readFile ../config/wm-scripts/apply-mode.sh);
  oskToggle = pkgs.writeShellScriptBin "osk-toggle" (builtins.readFile ../config/wm-scripts/osk-toggle.sh);
  gridLauncher = pkgs.writeShellScriptBin "grid-toggle" (builtins.readFile ../config/wm-scripts/grid.sh);
  hyprpanelToggle = pkgs.writeShellScriptBin "hyprpanel-toggle" (builtins.readFile ../config/wm-scripts/hyprpanel-toggle.sh);
  modeCycle = pkgs.writeShellScriptBin "mode-cycle" (builtins.readFile ../config/wm-scripts/mode-cycle.sh);

  # Lock wrapper: hyprlock, plus wvkbd raised over the lock (abovelock)
  # in tablet mode so the password is typable on the touchscreen.
  lockScreen = pkgs.writeShellScriptBin "lock-screen" (builtins.readFile ../config/wm-scripts/lock-screen.sh);

  # wvkbd with a direct-tap symbol row prepended to the symbols layer
  # (portrait + landscape). The stock layout only exposes those symbols
  # as swipe labels, unusable for a password on the lock screen.
  # --replace-fail fails the build if the upstream layout changes.
  wvkbdSymbols = pkgs.wvkbd.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      for arr in keys_special keys_landscape_special; do
        substituteInPlace layout.mobintl.h \
          --replace-fail \
            "static struct key $arr[] = {" \
            "static struct key $arr[] = {
  {\"!\", \"!\", 1.0, Code, KEY_1, 0, Shift},
  {\"@\", \"@\", 1.0, Code, KEY_2, 0, Shift},
  {\"#\", \"#\", 1.0, Code, KEY_3, 0, Shift},
  {\"\$\", \"\$\", 1.0, Code, KEY_4, 0, Shift},
  {\"%\", \"%\", 1.0, Code, KEY_5, 0, Shift},
  {\"^\", \"^\", 1.0, Code, KEY_6, 0, Shift},
  {\"&\", \"&\", 1.0, Code, KEY_7, 0, Shift},
  {\"*\", \"*\", 1.0, Code, KEY_8, 0, Shift},
  {\"(\", \"(\", 1.0, Code, KEY_9, 0, Shift},
  {\")\", \")\", 1.0, Code, KEY_0, 0, Shift},
  {\"\", \"\", 0.0, EndRow},"
      done
    '';
  });

  # Re-source hyprgrass binds on every compositor config reload;
  # `hyprctl reload` silently drops runtime-registered gesture binds.
  hyprgrassWatch = pkgs.writeShellScriptBin "hyprgrass-watch" (
    builtins.replaceStrings
      ["@SOCAT@"]
      ["${pkgs.socat}/bin/socat"]
      (builtins.readFile ../config/wm-scripts/hyprgrass-watch.sh)
  );

  # Touch app-grid launcher (config/grinch). GTK3, not GTK4: GTK4
  # layer-shell surfaces drop wl_touch events on Hyprland.
  appGrid = pkgs.rustPlatform.buildRustPackage {
    pname = "grinch";
    version = "1.0.0";
    src = ../config/grinch;
    cargoLock.lockFile = ../config/grinch/Cargo.lock;
    nativeBuildInputs = with pkgs; [pkg-config wrapGAppsHook3];
    buildInputs = with pkgs; [
      gtk3
      gtk-layer-shell
      librsvg
      gdk-pixbuf
      glib
    ];
  };

  # Loading the plugin at config-parse time crashes Hyprland 0.52.1;
  # load via hyprctl once the session is up. Polls for the IPC socket
  # and the plugin's keywords before sourcing the binds.
  loadHyprgrass = pkgs.writeShellScriptBin "load-hyprgrass" ''
    set -u
    LOG=''${XDG_RUNTIME_DIR:-/tmp}/load-hyprgrass.log
    exec >>"$LOG" 2>&1
    echo "=== $(date '+%T') load-hyprgrass starting ==="
    HCTL=${pkgs.hyprland}/bin/hyprctl

    for _ in $(seq 1 100); do
      "$HCTL" version >/dev/null 2>&1 && break
      sleep 0.1
    done
    echo "hyprctl reachable"

    "$HCTL" plugin load ${pkgs.hyprlandPlugins.hyprgrass}/lib/libhyprgrass.so
    echo "plugin load issued"

    for i in $(seq 1 50); do
      "$HCTL" getoption plugin:touch_gestures:sensitivity 2>/dev/null \
        | grep -q '^float:' && { echo "plugin ready after $i polls"; break; }
      sleep 0.1
    done

    "$HCTL" keyword source /etc/hypr/gestures-binds.conf
    SENS=$("$HCTL" getoption plugin:touch_gestures:sensitivity 2>/dev/null \
             | awk '/^float:/ {print $2}')
    echo "post-source sensitivity = $SENS (expected 4.000000)"
  '';

in {
  # Compositor + lock screen. hyprlock authenticates via PAM
  # (auto-created `hyprlock` service); locking goes through the
  # lock-screen wrapper ($mod+CTRL+Q, hypridle).
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  programs.hyprlock.enable = true;

  # Power button suspends; long-press (~3s) powers off.
  services.logind.settings.Login = {
    HandlePowerKey = "suspend";
    HandlePowerKeyLongPress = "poweroff";
  };

  # Touchscreen gesture options + binds, sourced live by load-hyprgrass
  # (config-parse-time loading crashes Hyprland 0.52.1).
  environment.etc."hypr/gestures-binds.conf".text = ''
    plugin {
      touch_gestures {
        sensitivity = 4.0
        workspace_swipe_fingers = 3
        long_press_delay = 400
        edge_margin = 32
        experimental {
          send_cancel = 1
        }
      }
    }

    hyprgrass-bind = , swipe:3:u, exec, grid-toggle
    hyprgrass-bind = , swipe:4:d, killactive

    # 2-finger vertical swipe sends an arrow key to the focused window.
    hyprgrass-bind = , swipe:2:d, sendshortcut, , Down,
    hyprgrass-bind = , swipe:2:u, sendshortcut, , Up,
  '';

  # XDG portal: required for screenshare, file pickers
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
    ];
    config.hyprland.default = ["hyprland" "gtk"];
  };

  # Packages
  environment.systemPackages = with pkgs; [
    # core
    hyprpanel
    hyprpaper
    hyprpicker
    hyprland-qtutils
    hyprcursor
    # Sleep/lock daemon; only lock-before-suspend is configured.
    hypridle

    # rotation
    iio-hyprland

    # Touchscreen gesture engine; native gestures only cover touchpad.
    hyprlandPlugins.hyprgrass

    # App OSK: squeekboard. Auto-popup is gated by the a11y gsetting
    # that apply-mode toggles per mode; layout via home-manager.
    squeekboard
    # Lock-screen OSK: wvkbd. squeekboard can't render over hyprlock
    # (input-method surface torn down on lock); wvkbd's plain
    # layer-shell surface can be lifted with abovelock.
    wvkbdSymbols

    # auth
    polkit_gnome
    libsecret

    # utilities HyprPanel and config rely on
    brightnessctl
    playerctl
    pamixer
    pavucontrol
    networkmanagerapplet
    bluez
    bluez-tools
    blueman
    grim
    slurp
    wl-clipboard
    cliphist
    swappy
    libnotify

    # theming
    adw-gtk3
    adwaita-icon-theme
    papirus-icon-theme
    bibata-cursors

    # helpers
    modeDaemon
    applyMode
    oskToggle
    gridLauncher
    hyprpanelToggle
    modeCycle
    lockScreen
    loadHyprgrass
    hyprgrassWatch
    appGrid
  ];

  # Fonts
  fonts.packages = with pkgs; [
    jetbrains-mono
    material-symbols
    material-design-icons
    nerd-fonts.jetbrains-mono
    nerd-fonts.dejavu-sans-mono
    nerd-fonts.symbols-only
  ];

  # No fingerprint on the lock screen. fprintAuth defaults to
  # services.fprintd.enable (true here), and hyprlock runs a single PAM
  # conversation, so with pam_fprintd ordered first a typed password
  # blocks ~30s on the fingerprint timeout before falling through to
  # pam_unix. Must set false explicitly to override the default.
  security.pam.services.hyprlock.fprintAuth = false;

  # mode-daemon reads /dev/input/event* (SW_TABLET_MODE).
  users.users.${vars.mainUserName}.extraGroups = ["input" "video"];

  security.polkit.enable = true;

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
    TERMINAL = "alacritty";
  };

  # systemd user units
  systemd.user.services."iio-hyprland" = {
    description = "Auto-rotate display + touch based on IMU (iio-sensor-proxy)";
    partOf = ["graphical-session.target"];
    after = ["graphical-session.target"];
    # iio-hyprland popens `hyprctl … | jq` but isn't PATH-wrapped;
    # without jq + hyprctl on PATH it gets no data and aborts.
    path = with pkgs; [jq hyprland];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.iio-hyprland}/bin/iio-hyprland eDP-1";
      Restart = "on-failure";
      RestartSec = 3;
    };
  };

  systemd.user.services."mode-daemon" = {
    description = "ThinkPad X12 tablet-mode detection daemon";
    partOf = ["graphical-session.target"];
    after = ["graphical-session.target"];
    # PATH for the daemon's subprocess calls: the helpers + their deps.
    path =
      [applyMode oskToggle gridLauncher hyprpanelToggle]
      ++ (with pkgs; [coreutils systemd hyprland procps libnotify glib]);
    serviceConfig = {
      Type = "simple";
      ExecStart = "${modeDaemon}/bin/mode-daemon";
      Restart = "on-failure";
      RestartSec = 3;
    };
  };

}
