{
  config,
  pkgs,
  lib,
  self,
  ...
}: let
  modules = self.lib.modules;
in {
  imports = [
    (modules.getHomeModule "zsh")
    (modules.getHomeModule "packages")
    (modules.getHomeModuleDir "atuin")
    (modules.getHomeModuleDir "git")
    (modules.getHomeModule "bat")
    (modules.getHomeModule "btop")
    (modules.getHomeModuleDir "oh-my-posh")
    (modules.getHomeModuleDir "nvim")
    (modules.getHomeModuleDir "aws")
    (modules.getHomeModule "yazi")
    (modules.getHomeModuleDir "stylix")
    (modules.getHomeModule "tailscale")
  ];

  options.configurationName = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
  };

  config = {
    nixpkgs.config.allowUnfree = true;
    programs.home-manager.enable = true;
    stylix.enable = lib.mkDefault true;
    stylix.autoEnable = false;
    stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/everforest.yaml";
    stylix.polarity = "dark";
  };
}
