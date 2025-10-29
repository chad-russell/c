{self, ...}: let
  # Helper to create paths from the flake root
  fromRoot = path: self + "/${path}";

  # Helper to get all subdirectory names from a path
  getDirNames = path: let
    dirPath = fromRoot path;
    dirContents = builtins.readDir dirPath;
    # Filter to only include directories using a simpler approach
    dirNames = builtins.attrNames (
      builtins.listToAttrs (
        map
        (name: {
          inherit name;
          value = dirContents.${name};
        })
        (builtins.filter (name: dirContents.${name} == "directory") (builtins.attrNames dirContents))
      )
    );
  in
    dirNames;
in {
  inherit fromRoot getDirNames;

  # Machine-related helpers
  getMachineHome = name: fromRoot "machines/${name}/home.nix";
  getMachineNixos = name: fromRoot "machines/${name}/configuration.nix";
  getMachineDefault = name: fromRoot "machines/${name}/default.nix";
  getMachineNames = getDirNames "machines";

  # Module-related helpers
  getHomeModule = name: fromRoot "modules/home/${name}.nix";
  getNixosModule = name: fromRoot "modules/nixos/${name}.nix";
  getHomeModuleDir = name: fromRoot "modules/home/${name}";
  getNixosModuleDir = name: fromRoot "modules/nixos/${name}";

  defaultSecretsFile = fromRoot "secrets/secrets.yaml";
}
