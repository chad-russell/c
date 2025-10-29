{config, ...}: {
  config = {
    programs.ssh = {
      enable = true;
      matchBlocks = {
        "*" = {
          extraOptions = {
            AddKeysToAgent = "yes";
            IdentityFile = "${config.home.homeDirectory}/.ssh/id_rsa";
          };
        };
      };
    };
  };
}
