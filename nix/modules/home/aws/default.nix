{
  config,
  pkgs,
  ...
}: {
  # AWS CLI
  home.packages = with pkgs; [
    awscli2
  ];

  home.file.".aws/config" = {
    source = config.lib.file.mkOutOfStoreSymlink ./config;
  };
}
