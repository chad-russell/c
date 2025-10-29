# Desktop module for cross-platform Home Manager configurations
# Compatible with both macOS/Darwin and Linux desktop systems
{
self,
pkgs,
...
}: let
    modules = self.lib.modules;
in {
    imports = [
        (modules.getHomeModuleDir "wezterm")
        (modules.getHomeModuleDir "markdown-oxide")
    ];

    home.packages = with pkgs; [
        bun
        pnpm
        typescript-language-server
        typescript
        gum
        cargo
        uv
        kubectl
        nodejs_24
    ];

    home.shellAliases = {
        code = "/Applications/Visual\\ Studio\\ Code.app/Contents/MacOS/Electron";
        cursor = "/Applications/Cursor.app/Contents/MacOS/Cursor";
    };
}
