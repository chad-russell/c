{lib, ...}: {
  config = {
    stylix.enable = false;
    dconf.enable = lib.mkForce false;
  };
}
