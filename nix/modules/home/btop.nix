{
  config,
  pkgs,
  ...
}: {
  home.packages = [pkgs.btop];

  stylix.targets.btop.enable = true;
}
