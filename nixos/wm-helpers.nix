{pkgs}: rec {
  modeDaemon = pkgs.writers.writePython3Bin "mode-daemon" {
    libraries = with pkgs.python3Packages; [evdev];
    doCheck = false;
  } (builtins.readFile ../config/wm-scripts/mode-daemon.py);

  applyMode = pkgs.writeShellScriptBin "apply-mode" (builtins.readFile ../config/wm-scripts/apply-mode.sh);
  oskToggle = pkgs.writeShellScriptBin "osk-toggle" (builtins.readFile ../config/wm-scripts/osk-toggle.sh);
  gridLauncher = pkgs.writeShellScriptBin "grid-toggle" (builtins.readFile ../config/wm-scripts/grid.sh);
  modeCycle = pkgs.writeShellScriptBin "mode-cycle" (builtins.readFile ../config/wm-scripts/mode-cycle.sh);

  # GTK3, not GTK4: GTK4 layer-shell surfaces drop wl_touch events on
  # wlroots compositors.
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

  all = [modeDaemon applyMode oskToggle gridLauncher modeCycle appGrid];
}
