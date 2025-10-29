{
  pkgs,
  config,
  lib,
  ...
}: {
  config = lib.mkIf config.stylix.enable {
    home.file.".cache/wal/colors".source = pkgs.writeText "pywal-colors" ''
      #${config.stylix.base16.base00-hex}
      #${config.stylix.base16.base01-hex}
      #${config.stylix.base16.base02-hex}
      #${config.stylix.base16.base03-hex}
      #${config.stylix.base16.base04-hex}
      #${config.stylix.base16.base05-hex}
      #${config.stylix.base16.base06-hex}
      #${config.stylix.base16.base07-hex}
      #${config.stylix.base16.base08-hex}
      #${config.stylix.base16.base09-hex}
      #${config.stylix.base16.base0A-hex}
      #${config.stylix.base16.base0B-hex}
      #${config.stylix.base16.base0C-hex}
      #${config.stylix.base16.base0D-hex}
      #${config.stylix.base16.base0E-hex}
      #${config.stylix.base16.base0F-hex}
    '';

    home.file.".cache/wal/colors.json".source = pkgs.writeText "pywal-colors-json" ''
      {
          "special": {
              "background": "#${config.stylix.base16.base00-hex}",
              "foreground": "#${config.stylix.base16.base07-hex}",
              "cursor": "#${config.stylix.base16.base07-hex}"
          },
          "colors": {
              "color0": "#${config.stylix.base16.base00-hex}",
              "color1": "#${config.stylix.base16.base01-hex}",
              "color2": "#${config.stylix.base16.base02-hex}",
              "color3": "#${config.stylix.base16.base03-hex}",
              "color4": "#${config.stylix.base16.base04-hex}",
              "color5": "#${config.stylix.base16.base05-hex}",
              "color6": "#${config.stylix.base16.base06-hex}",
              "color7": "#${config.stylix.base16.base07-hex}",
              "color8": "#${config.stylix.base16.base08-hex}",
              "color9": "#${config.stylix.base16.base09-hex}",
              "color10": "#${config.stylix.base16.base0A-hex}",
              "color11": "#${config.stylix.base16.base0B-hex}",
              "color12": "#${config.stylix.base16.base0C-hex}",
              "color13": "#${config.stylix.base16.base0D-hex}",
              "color14": "#${config.stylix.base16.base0E-hex}",
              "color15": "#${config.stylix.base16.base0F-hex}"
          }
      }
    '';
  };
}
