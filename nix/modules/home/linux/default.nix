{
  self,
  pkgs,
  ...
}: {
  imports = [];

  config = {
    home.packages = with pkgs; [
      cyme
      lsof
    ];
  };
}
