{...}: {
  nix.settings = {
    experimental-features = ["nix-command" "flakes"];

    auto-optimise-store = true;
    keep-outputs = true;
    keep-derivations = true;

    min-free = 5368709120; # 5 GiB: trigger automatic GC when free space drops below
    max-free = 21474836480; # 20 GiB: stop the automatic GC once this much is free
  };

  nix.optimise.automatic = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
    persistent = true;
  };
}
