{...}: {
  nix.settings = {
    experimental-features = ["nix-command" "flakes"];

    auto-optimise-store = true;
    keep-outputs = true;
    keep-derivations = true;

    min-free = 5368709120; # 5 GiB
    max-free = 21474836480; # 20 GiB
  };

  nix.optimise.automatic = true;
}
