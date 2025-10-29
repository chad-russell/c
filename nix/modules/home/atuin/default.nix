{
  config,
  pkgs,
  lib,
  ...
}: {
  # Ensure the atuin directory exists
  home.file.".local/share/atuin/.keep" = {
    text = "";
  };

  programs.atuin = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      auto_sync = true;
      sync_frequency = "5m";
      sync_address = "http://homelab:6767";
      keymap_mode = "vim-insert";
    };
  };
}
