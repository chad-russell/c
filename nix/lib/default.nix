{
  self,
  inputs,
  outputs,
  nixpkgs,
  ...
}: {
  # System utilities
  forAllSystems = f:
    nixpkgs.lib.genAttrs [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ]
    f;

  # Core configuration modules
  modules = import ./modules.nix {inherit self;};
  config = import ./config.nix;

  # System-specific configurations
  system = import ./system.nix {inherit self inputs outputs nixpkgs;};
  home = import ./home.nix {inherit self inputs outputs nixpkgs;};
  nixos = import ./nixos.nix {inherit self inputs outputs nixpkgs;};

  # Machine configurations
  machines = machineArgs: import ./machines.nix (machineArgs // {inherit self;});
}
