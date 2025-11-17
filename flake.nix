{
  description = "NixOS configurations for homelab cluster";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    disko.url = "github:nix-community/disko";
    nixos-anywhere.url = "github:nix-community/nixos-anywhere";
    quadlet-nix.url = "github:SEIAROTg/quadlet-nix";
  };

  outputs = { self, nixpkgs, disko, nixos-anywhere, quadlet-nix }: {
    # k2 configuration
    nixosConfigurations.k2 = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit disko; };
      modules = [
        ./cn/nix/k2/configuration.nix
        ./cn/nix/k2/disk-config.nix
        ./cn/nix/common/hardware-configuration.nix
        disko.nixosModules.disko
        quadlet-nix.nixosModules.quadlet
      ];
    };

    # k3 configuration
    nixosConfigurations.k3 = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit disko; };
      modules = [
        ./cn/nix/k3/configuration.nix
        ./cn/nix/k3/disk-config.nix
        ./cn/nix/common/hardware-configuration.nix
        disko.nixosModules.disko
        quadlet-nix.nixosModules.quadlet
      ];
    };
  };
}

