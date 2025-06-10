{pkgs, ...}: let
  vars = import ./variables.nix;
in {
  # System Packages and Programs
  programs.nix-ld.enable = true; # Fixes some issues with dynamically linked executables
  programs.tmux.enable = true;
  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };
  programs.tcpdump.enable = true;
  services.fwupd.enable = true;
  programs.git.enable = true;
  environment.systemPackages = with pkgs; [
    nano
    wget
    htop
    neofetch
    wl-screenrec
    wl-clipboard
    gcc_multi
    dig
    traceroute
    ripgrep
    fzf
    cargo
    unzip
  ];

  # Timezone
  time.timeZone = "Europe/Rome";

  # i18n
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
  networking.hostName = vars.hostName;
  networking.networkmanager.enable = true;
  networking.firewall.enable = true;

  # Power Profiles
  services.auto-cpufreq.enable = true;
  services.auto-cpufreq.settings = {
    battery = {
      governor = "powersave";
      turbo = "never";
    };
    charger = {
      governor = "performance";
      turbo = "auto";
    };
  };

  # Thunderbolt
  services.hardware.bolt.enable = true;

  # Bluetooth
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = false;
    settings.General.Enable = "Source,Sink,Media,Socket";
  };
}
