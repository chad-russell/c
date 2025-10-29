{
  config,
  pkgs,
  ...
}: {
  home.shellAliases = {
    code = "/Applications/Visual\\ Studio\\ Code.app/Contents/MacOS/Electron";
    cursor = "/Applications/Cursor.app/Contents/MacOS/Cursor";
  };

  launchd.agents.ha-battery-percentage = let
    update-battery = pkgs.writeShellScriptBin "update-ha-battery" ''
      AUTH_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiIyYTNmOGI2ODFiYWY0ZjI3ODkyNzJjODBiNjQzNTFjOCIsImlhdCI6MTczODcyMDc5MCwiZXhwIjoyMDU0MDgwNzkwfQ.yfSF1se-WGTjFbJP2ZgLMOjn1a8C-Rsd7yiMklIMG_c"
      BATTERY_PERCENTAGE=$(pmset -g batt | grep -o '[0-9]\+%' | awk -F% '{print $1}')
      SERVER_URL="https://homeassistant.crussell.io/api/states/input_number.mpro_battery"
      ${pkgs.httpie}/bin/http --ignore-stdin POST "$SERVER_URL" "Authorization:Bearer $AUTH_TOKEN" state="$BATTERY_PERCENTAGE"
    '';
  in {
    enable = true;
    config = {
      Program = "${update-battery}/bin/update-ha-battery";
      StartInterval = 60;
    };
  };
}
