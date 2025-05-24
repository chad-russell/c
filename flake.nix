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

      # Package sets for different systems
      forAllSystems = nixpkgs.lib.genAttrs ["x86_64-linux" "aarch64-darwin"];
      pkgsFor = system: import nixpkgs { inherit system; };
    in
    {
      nixosConfigurations = {
        c1 = mkHost "c1" 1;
        c2 = mkHost "c2" 2;
        c3 = mkHost "c3" 3;
        c4 = mkHost "c4" 4;
      };

      # Apps for deployment and management
      apps = forAllSystems (system:
        let
          pkgs = pkgsFor system;
          
          # Python deployment script with dependencies
          deployScript = pkgs.writeShellApplication {
            name = "home-deploy";
            
            runtimeInputs = with pkgs; [
              nixos-anywhere
              sops
              age
              ssh-to-age
              (python3.withPackages (ps: with ps; [
                pyyaml
                rich
              ]))
            ];
            
            text = ''
              exec python3 ${./scripts/deploy.py} "$@"
            '';
          };
          
        in {
          deploy = {
            type = "app";
            program = "${deployScript}/bin/home-deploy";
          };
          
          # Alias for the default app
          default = {
            type = "app";
            program = "${deployScript}/bin/home-deploy";
          };
        }
      );

      # Development shell for managing the cluster
      devShells = forAllSystems (system:
        let
          pkgs = pkgsFor system;
        in {
          default = pkgs.mkShell {
            buildInputs = with pkgs; [
              nixos-anywhere
              sops
              age
              ssh-to-age
              (python3.withPackages (ps: with ps; [
                pyyaml
                rich
              ]))
            ];
            
            shellHook = ''
              echo "🚀 Home Cluster Development Environment"
              echo "Available commands:"
              echo "  nix run .#deploy       - Deploy to all nodes"
              echo "  nix run .#deploy c1    - Deploy to specific node"
              echo "  python3 scripts/deploy.py --help  - See all options"
              echo ""
              echo "Or use the old script: ./deploy.sh"
            '';
          };
        }
      );
    };
}
