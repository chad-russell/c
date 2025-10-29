{self, ...}: {
  system = "x86_64-linux";
  username = "crussell";
  stateVersion = "23.05";

  nixosModules = [];

  homeModules = [
    (import (self.lib.modules.getHomeModule "server"))
  ];
}
