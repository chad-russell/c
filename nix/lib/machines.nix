{
  self,
  nixos-hardware,
  disko,
  ...
}: let
  importMachine = machine:
    (import (self.lib.modules.getMachineDefault machine) {inherit nixos-hardware disko self;}) // {name = machine;};

  # Use the helper function to get machine names
  machineNames = self.lib.modules.getMachineNames;
in
  map importMachine machineNames
