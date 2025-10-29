{
  config,
  pkgs,
  ...
}: {
  config = {
    home.packages = with pkgs; [
      neovim
      lua-language-server
      typescript
    ];

    home.file.".config/nvim" = {
      source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix/modules/home/nvim/config";
      recursive = true;
    };
  };
}