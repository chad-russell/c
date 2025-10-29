{
config,
pkgs,
...
}: {
    config = {
        home.packages = with pkgs; [
            wezterm
        ];

        # home.file.".config/wezterm/wezterm.lua" = {
        # source = ./config/wezterm.lua;
        # };
        # home.file.".config/wezterm/wezterm.lua".text = builtins.readFile ./config/wezterm.lua;
    };
}



