{self, ...}: {
  system = "x86_64-linux";
  username = "crussell";
  stateVersion = "25.05";

  homeModules = [
    (import (self.lib.modules.getHomeModule "desktop"))
  ];
}
