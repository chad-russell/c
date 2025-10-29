{
  pkgs,
  config,
  lib,
  ...
}: {
  config = with config.lib.stylix.colors.withHashtag;
    lib.mkIf config.stylix.enable {
      home.file.".cache/wal/colors".source = pkgs.writeText "pywal-colors" ''
        ${base00}
        ${base01}
        ${base02}
        ${base03}
        ${base04}
        ${base05}
        ${base06}
        ${base07}
        ${base08}
        ${base09}
        ${base0A}
        ${base0B}
        ${base0C}
        ${base0D}
        ${base0E}
        ${base0F}
      '';

      home.file.".cache/wal/colors.json".source = pkgs.writeText "pywal-colors-json" ''
        {
            "alpha": 100,
            "special": {
                "background": "${base00}",
                "foreground": "${base06}",
                "cursor": "${base06}"
            },
            "colors": {
                "color0": "${base00}",
                "color1": "${base01}",
                "color2": "${base02}",
                "color3": "${base03}",
                "color4": "${base04}",
                "color5": "${base05}",
                "color6": "${base06}",
                "color7": "${base07}",
                "color8": "${base08}",
                "color9": "${base09}",
                "color10": "${base0A}",
                "color11": "${base0B}",
                "color12": "${base0C}",
                "color13": "${base0D}",
                "color14": "${base0E}",
                "color15": "${base0F}"
            }
        }
      '';
    };
}
