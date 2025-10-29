{
  config,
  pkgs,
  self,
  lib,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
  ];

  system.stateVersion = "23.05";
}
