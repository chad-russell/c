{
  self,
  pkgs,
  inputs,
  ...
}: {
  home.packages = [
    inputs.vicinae.packages.${pkgs.system}.default
  ];
}
