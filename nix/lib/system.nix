{
  self,
  inputs,
  outputs,
  nixpkgs,
  ...
}: let
  lib = nixpkgs.lib;
  home = import ./home.nix {inherit self inputs outputs nixpkgs;};
  nixos = import ./nixos.nix {inherit self inputs outputs nixpkgs;};
  modules = self.lib.modules;

  # Function to create both home and NixOS configurations for a system
  mkSystem = {
    name,
    system ? "x86_64-linux",
    username ? "crussell",
    stateVersion,
    homeModules ? [],
    nixosModules ? [],
  }: let
    isDarwin = lib.hasSuffix "-darwin" system;
    isLinux = lib.hasSuffix "-linux" system;
    hasNixosConfig = builtins.pathExists (modules.getMachineNixos name);

    mkHomeConfig = if isDarwin then home.mkDarwinHome else home.mkLinuxHome;

    homeConfig = mkHomeConfig {
      inherit username stateVersion homeModules;
      configurationName = name;
    };

    nixosConfig =
      if isLinux && hasNixosConfig then
        nixos.mkNixConfig {
          inherit system username nixosModules;
          hostname = name;
        }
      else null;
  in {
    homeConfigurations = {"${name}" = homeConfig;};
    nixosConfigurations = lib.optionalAttrs (nixosConfig != null) {"${name}" = nixosConfig;};
  };

  # Function to create multiple systems at once
  mkSystems = systems:
    lib.foldl'
    (
      acc: system: let
        result = mkSystem system;
      in {
        homeConfigurations = acc.homeConfigurations // result.homeConfigurations;
        nixosConfigurations = acc.nixosConfigurations // result.nixosConfigurations;
      }
    )
    {
      homeConfigurations = {};
      nixosConfigurations = {};
    }
    systems;
in {
  inherit mkSystem mkSystems;
}
