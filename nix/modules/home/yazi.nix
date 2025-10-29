{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    yazi
  ];

  stylix.targets.yazi.enable = true;
}
