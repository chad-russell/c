{ config, pkgs, lib, ... }:

{
  imports = [
    ./disk-config.nix
  ];

  # NixOS Anywhere settings for Hetzner Cloud
  # Refer to: https://github.com/nix-community/nixos-anywhere-examples/blob/main/hetzner-cloud/configuration.nix

  boot.loader.systemd-boot.enable = lib.mkForce false; # systemd-boot is not strictly necessary for nixos-anywhere 
  boot.loader.grub = {
    enable = true;
    device = "nodev"; # We let disko handle the boot loader installation to the correct device
    efiSupport = true;
    useOSProber = false;
  };

  # Basic networking for Hetzner Cloud (assumes DHCP)
  networking.useDHCP = true;
  networking.hostName = "hetzner-vps"; # Set your desired hostname

  # SSH access
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "yes"; # Change to "prohibit-password" after initial setup
  };

  # Add your user and SSH public key(s)
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDsHOYNAog8L5SAhKp551g4oJFSi/GB+Fg38mmBLhwbrCUSfVSFqKeaOuRlLCQVnTWPZYfyp6cTibHBeigky6fjKhQgKnUJgwPdHjxhSvk7m6zgGj71s45bFT918E1J8hysN2wrijoo6oJ1zSeX3FIWOcFZVR4MHxCdYCMr+4mJp8tb1oQRea6GxCFGCms7DoNii+gWL/K2KZTMHKZ6l9Nf5CXq/6+a9Pfog3XuRlpTxLlIVj8YMC8TeRki0m9mG4+gk4OtCzACL/ngY0OxRWN4IN0NhFZOO5FHwytMR9/yNiAzafzaIt2szd69nmPG3DrXSUN1nXZKR78kM5O1kIaEKNeWJjhTXuDF7DtMF61TlXDWmsFxQbF9TAWK7nXJMUzAgXY1vIkTiYV3uwBB9upyKmXD/M5U1cFDvY6sSnINHxaqXp7/IoEHsXzHKmR5yhGLVszMzMlINBTxrWEYbjzNJPEvWeLCt3EbU4LPVffc8MA+l9zujSDjMO78uC7k/Ek= chadrussell@Chads-MacBook-Pro.local"
  ];
  users.users.myuser = { # Replace 'myuser' with your desired username
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # For sudo access
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDsHOYNAog8L5SAhKp551g4oJFSi/GB+Fg38mmBLhwbrCUSfVSFqKeaOuRlLCQVnTWPZYfyp6cTibHBeigky6fjKhQgKnUJgwPdHjxhSvk7m6zgGj71s45bFT918E1J8hysN2wrijoo6oJ1zSeX3FIWOcFZVR4MHxCdYCMr+4mJp8tb1oQRea6GxCFGCms7DoNii+gWL/K2KZTMHKZ6l9Nf5CXq/6+a9Pfog3XuRlpTxLlIVj8YMC8TeRki0m9mG4+gk4OtCzACL/ngY0OxRWN4IN0NhFZOO5FHwytMR9/yNiAzafzaIt2szd69nmPG3DrXSUN1nXZKR78kM5O1kIaEKNeWJjhTXuDF7DtMF61TlXDWmsFxQbF9TAWK7nXJMUzAgXY1vIkTiYV3uwBB9upyKmXD/M5U1cFDvY6sSnINHxaqXp7/IoEHsXzHKmR5yhGLVszMzMlINBTxrWEYbjzNJPEvWeLCt3EbU4LPVffc8MA+l9zujSDjMO78uC7k/Ek= chadrussell@Chads-MacBook-Pro.local"
    ];
  };

  # Allow nixos-anywhere to rebuild the system
  system.extraSystemBuilderCmds = lib.mkBefore ''
    cp ${config.system.build.toplevel}/sw/bin/nixos-rebuild /run/current-system/sw/bin/
  '';

  # Basic packages
  environment.systemPackages = with pkgs; [
    git
    vim # or your preferred editor
  ];

  # Set the state version
  system.stateVersion = "25.05"; # Or your desired NixOS version
} 