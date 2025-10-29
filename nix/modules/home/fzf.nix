{
  config,
  pkgs,
  ...
}: {
  home.packages = [pkgs.fzf];

  stylix.targets.fzf.enable = true;
}
