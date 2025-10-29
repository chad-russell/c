{
  description = "home-manager config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix.url = "github:danth/stylix";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-ai-tools = {
      url = "github:numtide/nix-ai-tools";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    vicinae = {
      url = "github:vicinaehq/vicinae";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    nixos-hardware,
    disko,
    ...
  } @ inputs: let
    inherit (self) outputs;

    # Library imports with clearer, more concise names
    lib = import ./lib {inherit self inputs outputs nixpkgs;};

    formatterName = "alejandra";

    # Helper function to generate outputs for each system
    inherit (lib) forAllSystems;

    # Import machine configurations from external files
    machineConfigs = lib.machines {
      inherit nixos-hardware disko;
    };

    allSystems = lib.system.mkSystems machineConfigs;

    # convenience: function that builds a package set with the wanted system
    forSystem = system: pkgs: import pkgs {inherit system;};
  in {
    # Add formatter for each system
    formatter =
      forAllSystems (system: nixpkgs.legacyPackages.${system}.${formatterName});

    # Basic development shell for the main flake
    devShells = forAllSystems (system: {
      default = let
        pkgs = nixpkgs.legacyPackages.${system};
      in
        pkgs.mkShell {
          name = "nix-config";
          packages = with pkgs; [
            git
            gh
            tailscale
          ];
        };
    });

    lib = {
      inherit (lib) home nixos modules system;
    };

    # Expose the configurations
    inherit (allSystems) homeConfigurations;
    inherit (allSystems) nixosConfigurations;

    apps = forAllSystems (system: {
      clean-home = {
        type = "app";
        program = let
          pkgs = nixpkgs.legacyPackages.${system};
        in
          toString (pkgs.writeShellScript "clean-home" ''
            #!/usr/bin/env bash
            set -euo pipefail

            echo "Cleaning up old home-manager generations..."

            # Keep only the current generation
            if [[ "${system}" == *"darwin"* ]]; then
              # macOS specific commands
              ${pkgs.nix}/bin/nix-env --profile "$HOME/.local/state/nix/home-manager/profile" --delete-generations old
            else
              # Linux specific commands
              ${pkgs.nix}/bin/nix-env --profile "$HOME/.local/state/home-manager/profile" --delete-generations old
            fi

            # Run garbage collection to free up space
            echo "Running garbage collection..."
            ${pkgs.nix}/bin/nix-collect-garbage -d

            echo "Cleanup complete!"
          '');
        meta = {
          description = "Clean up old home-manager generations";
          mainProgram = "clean-home";
        };
      };
    });
  };
}
