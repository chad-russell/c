{
  config,
  pkgs,
  ...
}: {
  programs.oh-my-posh = {
    enable = true;
    enableZshIntegration = true;
    # useTheme = "pure"; # https://ohmyposh.dev/docs/themes
    settings =
      builtins.fromJSON
      (builtins.unsafeDiscardStringContext (builtins.readFile ./config.json));
  };
}
