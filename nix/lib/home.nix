{
  self,
  inputs,
  outputs,
  nixpkgs,
  ...
}: let
  lib = nixpkgs.lib;

  modules = self.lib.modules;

  mkHomeUser = {
    architecture,
    username,
    configurationName,
    stateVersion,
    homeModules ? [],
  }: let
    pkgs = import nixpkgs {
      system = architecture;
      config = {
        allowUnfree = true;
        allowUnfreePredicate = _: true;
      };
    };
    isDarwin = architecture == "aarch64-darwin";
    homePrefix =
      if isDarwin
      then "/Users"
      else "/home";
    # Use current APIs from locked inputs (no compatibility branching)
    stylixModule = inputs.stylix.homeModules.stylix;
    standardModules = [
      {
        inherit configurationName;

        programs.home-manager.enable = true;

        nixpkgs.config.allowUnfree = true;
        nixpkgs.config.allowUnfreePredicate = _: true;

        home = {
          inherit username;
          homeDirectory = "${homePrefix}/${username}";
          stateVersion = stateVersion;
        };
      }
      (import (modules.getHomeModuleDir "common"))
      (import (modules.getMachineHome configurationName))
      (if isDarwin then (import (modules.getHomeModuleDir "darwin")) else (import (modules.getHomeModuleDir "linux")))
      stylixModule
    ];
  in
    inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      extraSpecialArgs = {inherit self inputs outputs;};
      modules =
        standardModules
        ++ homeModules;
    };
in {
  mkDarwinHome = {
    username,
    configurationName,
    stateVersion,
    homeModules ? [],
  }:
    mkHomeUser {
      inherit username configurationName stateVersion homeModules;
      architecture = "aarch64-darwin";
    };

  mkLinuxHome = {
    username,
    configurationName,
    stateVersion,
    homeModules ? [],
  }:
    mkHomeUser {
      inherit username configurationName stateVersion homeModules;
      architecture = "x86_64-linux";
    };
}
