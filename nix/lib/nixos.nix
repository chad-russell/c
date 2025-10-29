{
  self,
  inputs,
  outputs,
  nixpkgs,
  ...
}: {
  mkNixConfig = let
    libModules = self.lib.modules;
    importMachine = hostname: import (libModules.getMachineNixos hostname);
  in
    {
      system,
      username,
      hostname,
      nixosModules ? [],
    }: let
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
          allowUnfreePredicate = _: true;
        };
      };
      baseModule = {
        options.hostname = nixpkgs.lib.mkOption {type = nixpkgs.lib.types.str;};
        config = {
          networking.hostName = hostname;
          users.defaultUserShell = pkgs.zsh;
          time.timeZone = "America/New_York";
          i18n.defaultLocale = "en_US.UTF-8";
          i18n.extraLocaleSettings = {
            LC_ADDRESS = "en_US.UTF-8";
            LC_IDENTIFICATION = "en_US.UTF-8";
            LC_MEASUREMENT = "en_US.UTF-8";
            LC_MONETARY = "en_US.UTF-8";
            LC_NAME = "en_US.UTF-8";
            LC_NUMERIC = "en_US.UTF-8";
            LC_PAPER = "en_US.UTF-8";
            LC_TELEPHONE = "en_US.UTF-8";
            LC_TIME = "en_US.UTF-8";
          };
          services.openssh.enable = true;
          programs.ssh.startAgent = true;
          services.tailscale.enable = true;
          services.tailscale.useRoutingFeatures = "client";
          nix.settings = {
            experimental-features = ["nix-command" "flakes"];
            auto-optimise-store = true;
          };
          boot.loader.systemd-boot = {
            enable = true;
            configurationLimit = 10;
          };
          boot.loader.efi.canTouchEfiVariables = true;
        };
      };
    in
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {inherit self inputs outputs;};
        modules =
          [
            (import (self.lib.modules.getNixosModuleDir "common"))
            (importMachine hostname)
            (import (self.lib.modules.getNixosModule "system/user"))
            baseModule
            {inherit username hostname;}
          ]
          ++ nixosModules;
        pkgs = pkgs;
      };
}
