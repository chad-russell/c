# Hetzner-specific NixOS configuration for nixos-anywhere
{ config, lib, pkgs, ... }:

{
  imports = [
    ./configuration.nix
  ];

  # Hetzner cloud servers typically use this interface name
  networking.useDHCP = false;
  networking.interfaces.enp1s0.useDHCP = true;

  # Enable SSH for remote access
  services.openssh = {
    enable = true;
    settings = {
      # TODO: Change back to "prohibit-password" once deployment is working reliably
      PermitRootLogin = "yes";
      PasswordAuthentication = false;  # Use keys for security
    };
  };

  # Basic security
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 80 443 ];
  };

  # Enable Tailscale by default
  services.tailscale.enable = true;

  # Enable nix flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Set timezone (adjust as needed)
  time.timeZone = "UTC";

  # Basic packages
  environment.systemPackages = with pkgs; [
    git
    curl
    htop
    vim
    tailscale
  ];

  # Hetzner-specific disk configuration
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/sda";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              size = "1M";
              type = "EF02"; # for grub MBR
            };
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };
    };
  };

  # Boot configuration
  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };

  system.stateVersion = "25.05";
} 