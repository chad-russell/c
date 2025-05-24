{ config, pkgs, lib, hostName, nodeNumber, ... }:

{
  # Basic system configuration
  system.stateVersion = "25.05";
  
  # Hostname and networking
  networking = {
    inherit hostName;
    useDHCP = false;
    
    # Static IP configuration based on node number
    interfaces.eno1.ipv4.addresses = [{
      address = "192.168.68.${toString (70 + nodeNumber)}";
      prefixLength = 24;
    }];
    
    defaultGateway = "192.168.68.1";
    nameservers = [ "192.168.68.1" "1.1.1.1" ];
    
    # Enable SSH
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 ];
    };
  };

  # Boot configuration
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    
    # Enable KVM
    kernelModules = [ "kvm-intel" "kvm-amd" ];
  };

  # User accounts
  users.users.crussell = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    # SSH keys are managed via nixos-anywhere extra-files
    uid = 1000;  # Ensure consistent UID across nodes
  };

  # SSH configuration
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # SOPS configuration - simplified since SSH keys handled by nixos-anywhere
  sops = {
    defaultSopsFile = ../secrets/secrets.yaml;
    age.keyFile = "/etc/sops/age/keys.txt";
    
    # Ready for additional secrets as needed
    secrets = {
      # Add other secrets here as needed
      # Example:
      # "database_password" = {
      #   owner = "myapp";
      #   group = "myapp"; 
      # };
    };
  };

  # Essential packages
  environment.systemPackages = with pkgs; [
    neovim
    git
    curl
    wget
    htop
    tree
    age
    sops
  ];

  # Enable flakes
  nix = {
    package = pkgs.nixFlakes;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
    
    # Automatic garbage collection
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  # Time zone
  time.timeZone = "America/New_York";  # Adjust as needed

  # Locale
  i18n.defaultLocale = "en_US.UTF-8";
} 