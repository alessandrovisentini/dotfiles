{
  pkgs,
  settings,
  ...
}: {
  # Sound server
  security.rtkit.enable = true;

  # Let Ardour lock memory
  security.pam.loginLimits = [
    {
      domain = "@audio";
      item = "memlock";
      type = "-";
      value = "unlimited";
    }
    {
      domain = "@audio";
      item = "rtprio";
      type = "-";
      value = "95";
    }
  ];

  # Setting LV2_PATH for the audio apps to find the plugins
  environment.sessionVariables.LV2_PATH = [
    "/etc/profiles/per-user/${settings.username}/lib/lv2"
    "/run/current-system/sw/lib/lv2"
  ];

  # Expose soundfonts
  environment.pathsToLink = ["/share/soundfonts"];

  # Low latency pipewire (but still usable)
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;

    extraConfig.pipewire.adjust-sample-rate = {
      "context.properties" = {
        "default.clock.rate" = 48000;
        "default.clock.min-quantum" = 256;
        "default.clock.quantum" = 512;
        "default.clock.max-quantum" = 2048;
      };
    };
  };

  users.users.${settings.username}.packages = with pkgs; [
    # Routing + effects
    easyeffects
    qpwgraph

    # Music
    musescore
    audacity
    transcribe
    tauon

    # CD ripping
    whipper
    cdrdao
    cdparanoia
    flac

    # DAW + plugin host
    ardour
    carla

    # Samplers
    sfizz
    drumgizmo
    x42-avldrums
    hydrogen

    # Synths
    surge-xt
    distrho-ports # vitalium and others
    odin2
    helm
    dexed
    cardinal
    setbfree
    zynaddsubfx

    # Effects
    lsp-plugins
    x42-plugins
    dragonfly-reverb
    airwindows-lv2
    chow-tape-model

    # Soundfonts
    soundfont-fluid
    soundfont-generaluser-gs
    soundfont-ydp-grand
  ];
}
