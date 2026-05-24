# GNOME core apps installed standalone so they're available without the
# GNOME desktop. epiphany and yelp are excluded to match excludePackages.
{
  config,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    baobab
    decibels
    gnome-calculator
    gnome-calendar
    gnome-characters
    gnome-clocks
    gnome-connections
    gnome-console
    gnome-contacts
    gnome-font-viewer
    gnome-logs
    gnome-maps
    gnome-music
    gnome-system-monitor
    gnome-text-editor
    gnome-weather
    loupe
    nautilus
    papers
    showtime
    simple-scan
  ];

  fonts.packages = [pkgs.adwaita-fonts];

  programs.gnome-disks.enable = true;
  programs.seahorse.enable = true;
  services.gnome.sushi.enable = true;

  environment.sessionVariables.NAUTILUS_4_EXTENSION_DIR =
    "${config.system.path}/lib/nautilus/extensions-4";
  environment.pathsToLink = ["/share/nautilus-python/extensions"];
}
