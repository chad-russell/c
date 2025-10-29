{
  self,
  config,
  pkgs,
  lib,
  ...
}: {
  options = {
    username = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
  };

  config = lib.mkIf (config.username != null) {
    users.users.${config.username} = {
      isNormalUser = true;
      description = "${config.username}";
      extraGroups =
        ["wheel"]
        ++ (
          if config.virtualisation.podman.enable
          then ["podman"]
          else []
        );
      packages = with pkgs; [];
      openssh.authorizedKeys.keyFiles = [(self.lib.modules.fromRoot "modules/home/ssh/.ssh/id_rsa.pub")];
    };

    services.getty.autologinUser = config.username;
  };
}
