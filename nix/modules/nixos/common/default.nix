{
  config,
  lib,
  pkgs,
  self,
  ...
}: {
  imports = [
    (self.lib.modules.getNixosModule "system/binary-cache-client")
  ];

  # # Enable the binary cache for all machines
  # nix.binary-cache = {
  #   enable = true;
  #   cacheUrl = "http://homelab";
  #   requireSignature = false;
  # };

  # Optimize Nix performance
  nix.settings = {
    # Increase max-jobs for faster builds
    max-jobs = "auto";

    builders-use-substitutes = true;

    # Control Nix store garbage collection thresholds:
    # - min-free: When free disk space falls below this value (10GB),
    #   Nix will start garbage collection automatically
    # - max-free: After garbage collection, Nix will stop deleting
    #   when free disk space reaches this threshold (20GB)
    max-free = 20000000000; # 20GB
    min-free = 10000000000; # 10GB

    # Auto optimize the store
    auto-optimise-store = true;

    # Allow the cache server to build derivations
    trusted-users = ["nix-serve" "root" "@wheel"];
  };

  # Enable Podman for container management
  virtualisation.podman = {
    enable = lib.mkForce true;
    dockerCompat = true;
    # Required for containers under podman-compose to be able to talk to each other.
    defaultNetwork.settings.dns_enabled = true;
  };

  # Run garbage collection weekly
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
}
