{
  config,
  pkgs,
  ...
}: {
  programs.bat = {
    enable = true;
    config = {
      pager = "less -FR";
    };
  };

  stylix.targets.bat.enable = true;
}
