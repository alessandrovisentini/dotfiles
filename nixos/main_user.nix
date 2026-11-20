{
  pkgs,
  settings,
  ...
}: {
  nixpkgs.config.allowUnfree = true;

  # User and group
  users.users.${settings.username} = {
    isNormalUser = true;
    uid = 1000;
    group = settings.username;
    description = settings.username;
    extraGroups = ["networkmanager" "wheel" "video" "audio" "disk" "pcap" "input"];
  };
  users.groups.${settings.username} = {
    gid = 1000;
  };

  xdg.mime.enable = true;
  xdg.portal.enable = true;
  xdg.portal.wlr.enable = true;

  # Polkit
  security.polkit.enable = true;

  # dconf
  programs.dconf.enable = true;

  # Keyring
  services.gnome.gnome-keyring.enable = true;

  # Fonts
  fonts.packages = with pkgs; [
    nerd-fonts.dejavu-sans-mono
    adwaita-fonts
  ];

  # Qt theme
  qt = {
    enable = true;
    style = "adwaita-dark";
  };

  # Session variables
  environment.sessionVariables = {
    XDG_CACHE_HOME = "$HOME/.cache";
    XDG_CONFIG_HOME = "$HOME/.config";
    XDG_DATA_HOME = "$HOME/.local/share";
    XDG_STATE_HOME = "$HOME/.local/state";

    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
  };

  # Desktop defaults from the dotfiles
  programs.dconf.profiles.user.databases = [
    {keyfiles = [../config/desktop];}
  ];
}
