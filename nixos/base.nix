{
  pkgs,
  settings,
  ...
}: {
  # Timezone
  time.timeZone = "Europe/Rome";

  # Locale
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "it_IT.UTF-8";
    LC_IDENTIFICATION = "it_IT.UTF-8";
    LC_MEASUREMENT = "it_IT.UTF-8";
    LC_MONETARY = "it_IT.UTF-8";
    LC_NAME = "it_IT.UTF-8";
    LC_NUMERIC = "it_IT.UTF-8";
    LC_PAPER = "it_IT.UTF-8";
    LC_TELEPHONE = "it_IT.UTF-8";
    LC_TIME = "it_IT.UTF-8";
  };

  # Networking
  networking.hostName = settings.hostname;
  networking.networkmanager.enable = true;
  networking.networkmanager.plugins = with pkgs; [
    networkmanager-openvpn
  ];
  networking.firewall.enable = true;

  # Power button
  services.logind.settings.Login.HandlePowerKey = "suspend";
  services.logind.settings.Login.HandlePowerKeyLongPress = "poweroff";
}
