{
  config,
  pkgs,
  ...
}: {
  config = {
    home.packages = with pkgs; [
      markdown-oxide
    ];

    home.file.".config/moxide/settings.toml" = {
      source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix/modules/home/markdown-oxide/config/settings.toml";
      recursive = true;
    };
  };
}
