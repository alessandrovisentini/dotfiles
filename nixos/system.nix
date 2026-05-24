{pkgs, ...}: let
  vars = import ./variables.nix;
in {
  # Packages and programs
  programs.nix-ld.enable = true; # runs dynamically-linked binaries
  programs.tmux.enable = true;
  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };
  programs.tcpdump.enable = true;
  services.fwupd.enable = true;
  programs.git.enable = true;
  programs.git.lfs.enable = true;
  environment.systemPackages = with pkgs; [
    nano
    wget
    htop
    fastfetch
    wl-screenrec
    wl-clipboard
    gcc_multi
    dig
    traceroute
    ripgrep
    fzf
    unzip
  ];
  programs.bash.interactiveShellInit = ''
    eval "$(fzf --bash)"
  '';

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
  networking.hostName = vars.hostName;
  networking.networkmanager.enable = true;
  networking.networkmanager.plugins = with pkgs; [
    networkmanager-openvpn
  ];
  networking.firewall.enable = true;

  # Power profiles
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
}
