{
  self,
  lib,
  ...
}: {
  # Re-export the path utility functions from lib/modules
  inherit
    (import ../lib/modules {inherit self lib;})
    fromRoot
    getMachineHome
    getMachineNixos
    getMachineDefault
    getDirNames
    getMachineNames
    getHomeModule
    getNixosModule
    getHomeModuleDir
    getNixosModuleDir
    ;
}
