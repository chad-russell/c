{ config, pkgs, ... }:

{
  imports = [
    # It's best practice to let nixos-anywhere generate a hardware-specific
    # configuration for your bare-metal machine.
    ./hardware-configuration.nix
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Pin the kernel to a stable LTS version to avoid the e1000e driver bug.
  boot.kernelPackages = pkgs.linuxPackages_6_6;

  # Enable zram swap.
  zramSwap.enable = true;

  # Set your hostname.
  networking.hostName = "k2";

  # Enable the OpenSSH server.
  services.openssh.enable = true;

  # Enable the Cockpit web UI.
  services.cockpit.enable = true;

  # Define your user account.
  users.users.crussell = {
    isNormalUser = true;
    # Add user to the 'wheel' group to grant sudo privileges.
    extraGroups = [ "wheel" ];
    # CRITICAL: Add your SSH public key here to ensure you can log in.
    openssh.authorizedKeys.keys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDsHOYNAog8L5SAhKp551g4oJFSi/GB+Fg38mmBLhwbrCUSfVSFqKeaOuRlLCQVnTWPZYfyp6cTibHBeigky6fjKhQgKnUJgwPdHjxhSvk7m6zgGj71s45bFT918E1J8hysN2wrijoo6oJ1zSeX3FIWOcFZVR4MHxCdYCMr+4mJp8tb1oQRea6GxCFGCms7DoNii+gWL/K2KZTMHKZ6l9Nf5CXq/6+a9Pfog3XuRlpTxLlIVj8YMC8TeRki0m9mG4+gk4OtCzACL/ngY0OxRWN4IN0NhFZOO5FHwytMR9/yNiAzafzaIt2szd69nmPG3DrXSUN1nXZKR78kM5O1kIaEKNeWJjhTXuDF7DtMF61TlXDWmsFxQbF9TAWK7nXJMUzAgXY1vIkTiYV3uwBB9upyKmXD/M5U1cFDvY6sSnINHxaqXp7/IoEHsXzHKmR5yhGLVszMzMlINBTxrWEYbjzNJPEvWeLCt3EbU4LPVffc8MA+l9zujSDjMO78uC7k/Ek= chadrussell@Chads-MacBook-Pro.local"
    ];
  };

  # Set your time zone.
  time.timeZone = "America/New_York";

  # This is required by NixOS.
  system.stateVersion = "25.05";
}
