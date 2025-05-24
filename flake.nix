{
  description = "Home Compute Cluster - multi-node HA setup with SeaweedFS";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, disko, sops-nix, ... }:
    let
      system = "x86_64-linux";
      
      # Common configuration for all nodes
      commonModules = [
        disko.nixosModules.disko
        sops-nix.nixosModules.sops
        ./modules/common.nix
      ];
      
      # Helper function to create a host configuration
      mkHost = hostName: nodeNumber: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { 
          inherit nixpkgs-unstable;
          nodeNumber = nodeNumber;
          hostName = hostName;
        };
        modules = commonModules ++ [
          ./hosts/${hostName}/configuration.nix
          ./hosts/${hostName}/disko.nix
        ];
      };
    in
    {
      nixosConfigurations = {
        c1 = mkHost "c1" 1;
        c2 = mkHost "c2" 2;
        c3 = mkHost "c3" 3;
        c4 = mkHost "c4" 4;
      };

      # Development shell for managing the cluster
      devShells.${system}.default = nixpkgs.legacyPackages.${system}.mkShell {
        buildInputs = with nixpkgs.legacyPackages.${system}; [
          nixos-anywhere
          sops
          age
          ssh-to-age
        ];
      };
    };
}
