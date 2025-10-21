{
  description = "NixOS configuration for k2";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    disko.url = "github:nix-community/disko";
    nixos-anywhere.url = "github:nix-community/nixos-anywhere";
    quadlet-nix.url = "github:SEIAROTg/quadlet-nix";
  };

  outputs = { self, nixpkgs, disko, nixos-anywhere, quadlet-nix }: {
    nixosConfigurations.k2 = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit disko; }; # Pass disko to modules
      modules = [
        # Import the main system and disk configurations
        ./configuration.nix
        ./disk-config.nix
        # Import the disko module to handle partitioning
        disko.nixosModules.disko
        # Import quadlet-nix module for container management
        quadlet-nix.nixosModules.quadlet
      ];
    };
  };
}
