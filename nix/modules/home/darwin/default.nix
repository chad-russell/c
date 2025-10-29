{
  self,
  pkgs,
  ...
}: let
  modules = self.lib.modules;
in {
  imports = [
    (modules.getHomeModule "desktop")
  ];

  home.shellAliases = {
    code = "/Applications/Visual\\ Studio\\ Code.app/Contents/MacOS/Electron";
    cursor = "/Applications/Cursor.app/Contents/MacOS/Cursor";
  };
}
