{
  config,
  lib,
  ...
}: {
  options.nix.binary-cache = {
    enable = lib.mkEnableOption "Enable custom binary cache";
    cacheUrl = lib.mkOption {
      type = lib.types.str;
      default = "";
    };
    requireSignature = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
  };

  config = lib.mkIf config.nix.binary-cache.enable {
    nix.settings = {
      substituters = [config.nix.binary-cache.cacheUrl];
      trusted-public-keys = lib.mkIf config.nix.binary-cache.requireSignature [];
    };
  };
}
