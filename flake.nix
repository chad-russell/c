{
  description = "Home Compute Cluster -- test node 1";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixos-generators.url = "github:nix-community/nixos-generators";
    sops-nix.url = "github:Mic92/sops-nix";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    nixos-anywhere.url = "github:nix-community/nixos-anywhere";
    nixos-anywhere.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nixos-generators, sops-nix, disko, nixos-anywhere, ... }:
    let
      system = "x86_64-linux";

      makeNginxModule = import ./modules/nginx.nix;
      makeGatewayModule = import ./modules/gateway.nix;
      makeJellyfinModule = import ./modules/jellyfin.nix;
      cloudProxyModule = import ./modules/cloud-proxy.nix;
    in {
      packages.${system} = {
        nginx = nixos-generators.nixosGenerate {
          inherit system;
          format = "proxmox";
          modules = [ (makeNginxModule { }) ];
        };

        gateway = nixos-generators.nixosGenerate {
          inherit system;
          format = "proxmox";
          modules = [ (makeGatewayModule { inherit sops-nix; }) ];
        };

        jellyfin = nixos-generators.nixosGenerate {
          inherit system;
          format = "proxmox";
          modules = [ (makeJellyfinModule { }) ];
        };

        # Helper script for deploying the age key
        deploy-key = nixpkgs.legacyPackages.${system}.writeShellScriptBin "deploy-age-key" ''
          #!/bin/bash
          set -e
          
          if [ $# -eq 0 ]; then
            echo "Usage: $0 <VM_IP_ADDRESS>"
            echo "Example: $0 178.156.171.212"
            exit 1
          fi
          
          VM_IP="$1"
          KEY_FILE="age-key.txt"
          
          if [ ! -f "$KEY_FILE" ]; then
            echo "Error: $KEY_FILE not found in current directory"
            exit 1
          fi
          
          echo "Deploying age key to VM at $VM_IP..."
          scp "$KEY_FILE" "$VM_IP:/tmp/"
          ssh "$VM_IP" "mkdir -p /etc/sops/age"
          ssh "$VM_IP" "mv /tmp/$KEY_FILE /etc/sops/age/keys.txt && chmod 600 /etc/sops/age/keys.txt"
          echo "Age key deployed successfully!"
          
          echo "Testing secrets access..."
          ssh "$VM_IP" "tailscale-api-test"
        '';

        # nixos-anywhere CLI tool
        nixos-anywhere = nixos-anywhere.packages.${system}.default;
      };

      nixosConfigurations = {
        gateway = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [ (makeGatewayModule { includeBootConfig = true; inherit sops-nix; }) ];
        };

        nginx = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [ (makeNginxModule { includeBootConfig = true; }) ];
        };

        jellyfin = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [ (makeJellyfinModule { includeBootConfig = true; }) ];
        };

        # NixOS configuration for Hetzner VPS (used by nixos-anywhere)
        hetzner-bootstrap = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";

          modules = [
            ./hetzner-bootstrap/configuration.nix
            ./hetzner-bootstrap/disko-config.nix
            disko.nixosModules.disko
          ];
        };

        # Minimal cloud reverse proxy for Hetzner
        cloud-proxy = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [ cloudProxyModule ];
        };
      };
    };
}