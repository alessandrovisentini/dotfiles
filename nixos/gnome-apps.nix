# GNOME core apps + default font, decoupled from the GNOME desktop so
# they're installed whether or not gnome.nix is imported (e.g. a
# Hyprland-only setup). gnome.nix disables GNOME's own core-apps set so
# this is the single source. epiphany and yelp are omitted to match
# environment.gnome.excludePackages.
{
  config,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    baobab # disk usage
    decibels # audio player
    gnome-calculator
    gnome-calendar
    gnome-characters
    gnome-clocks
    gnome-connections # remote desktop
    gnome-console
    gnome-contacts
    gnome-font-viewer
    gnome-logs
    gnome-maps
    gnome-music
    gnome-system-monitor
    gnome-text-editor
    gnome-weather
    loupe # image viewer
    nautilus # files
    papers # document viewer
    showtime # video player
    simple-scan # scanner
  ];

  # GNOME default UI font.
  fonts.packages = [pkgs.adwaita-fonts];

  # Program modules GNOME's core-apps would otherwise enable.
  programs.gnome-disks.enable = true;
  programs.seahorse.enable = true;
  services.gnome.sushi.enable = true;

  # Let nautilus find python extensions.
  environment.sessionVariables.NAUTILUS_4_EXTENSION_DIR =
    "${config.system.path}/lib/nautilus/extensions-4";
  environment.pathsToLink = ["/share/nautilus-python/extensions"];
}
