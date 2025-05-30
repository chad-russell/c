# Hetzner-specific NixOS configuration for nixos-anywhere
{ config, lib, pkgs, ... }:

{
  imports = [
    ./configuration.nix
  ];

  # Hetzner cloud servers typically use this interface name
  networking.useDHCP = false;
  networking.interfaces.enp1s0.useDHCP = true;

  # Enable SSH for remote access (critical for deployment)
  services.openssh = {
    enable = true;
    settings = {
      # TODO: Change back to "prohibit-password" once deployment is working reliably
      PermitRootLogin = "yes";
      PasswordAuthentication = false;  # Use keys for security
    };
  };

  # Basic security (deployment-critical)
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 80 443 ];
  };

  # Root SSH key (required for nixos-anywhere deployment)
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDsHOYNAog8L5SAhKp551g4oJFSi/GB+Fg38mmBLhwbrCUSfVSFqKeaOuRlLCQVnTWPZYfyp6cTibHBeigky6fjKhQgKnUJgwPdHjxhSvk7m6zgGj71s45bFT918E1J8hysN2wrijoo6oJ1zSeX3FIWOcFZVR4MHxCdYCMr+4mJp8tb1oQRea6GxCFGCms7DoNii+gWL/K2KZTMHKZ6l9Nf5CXq/6+a9Pfog3XuRlpTxLlIVj8YMC8TeRki0m9mG4+gk4OtCzACL/ngY0OxRWN4IN0NhFZOO5FHwytMR9/yNiAzafzaIt2szd69nmPG3DrXSUN1nXZKR78kM5O1kIaEKNeWJjhTXuDF7DtMF61TlXDWmsFxQbF9TAWK7nXJMUzAgXY1vIkTiYV3uwBB9upyKmXD/M5U1cFDvY6sSnINHxaqXp7/IoEHsXzHKmR5yhGLVszMzMlINBTxrWEYbjzNJPEvWeLCt3EbU4LPVffc8MA+l9zujSDjMO78uC7k/Ek= chadrussell@Chads-MacBook-Pro.local"
  ];

  # Enable nix flakes (deployment requirement)
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Set timezone
  time.timeZone = "UTC";

  # Basic deployment packages (minimal set needed for deployment/management)
  environment.systemPackages = with pkgs; [
    git
    curl
    vim
  ];

  # Fixed Hetzner-specific disk configuration
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/sda";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              size = "2M";
              type = "EF02"; # for grub MBR
              priority = 1;
            };
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
                extraArgs = [ "-L" "nixos" ];
              };
            };
          };
        };
      };
    };
  };

  # Boot configuration - use device path directly
  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };

  system.stateVersion = "25.05";
} 