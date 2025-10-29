{pkgs, ...}: let
  ghostty-package =
    if pkgs.stdenv.hostPlatform.isLinux
    then pkgs.ghostty
    else null;
in {
  programs.ghostty = {
    enable = true;
    enableZshIntegration = true;
    package = ghostty-package;
    settings = {
      theme = "Everforest Dark - Hard";
      keybind = [
        "ctrl+b>h=new_split:left"
        "ctrl+b>j=new_split:down"
        "ctrl+b>k=new_split:up"
        "ctrl+b>l=new_split:right"
        "alt+h=goto_split:left"
        "alt+j=goto_split:down"
        "alt+k=goto_split:up"
        "alt+l=goto_split:right"
        "ctrl+j=toggle_split_zoom"
        "cmd+k=clear_screen"
        "ctrl+b>t=prompt_surface_title"
      ];
    };
  };
}
