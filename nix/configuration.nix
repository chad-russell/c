{ config, pkgs, ... }:

{
  imports = [
    # It's best practice to let nixos-anywhere generate a hardware-specific
    # configuration for your bare-metal machine.
    ./hardware-configuration.nix
    # Service modules
    ./services/karakeep.nix
    ./services/memos.nix
    ./services/papra.nix
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Pin the kernel to a stable LTS version to avoid the e1000e driver bug.
  boot.kernelPackages = pkgs.linuxPackages_6_6;

  # Enable zram swap.
  zramSwap.enable = true;

  # Enable hardware watchdog for automatic reboot on system hang
  boot.kernelModules = [ "iTCO_wdt" ];  # Intel TCO watchdog (common on Intel systems)
  systemd.watchdog.runtimeTime = "30s";  # Systemd will ping watchdog every 15s (half of 30s)
  systemd.watchdog.rebootTime = "2min";  # If systemd fails to respond, reboot after 2 minutes

  # Set your hostname.
  networking.hostName = "k2";

  # Enable systemd-networkd for network management
  systemd.network.enable = true;
  networking.useDHCP = false;

  # Enable the OpenSSH server.
  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "prohibit-password"; # Allow root login with SSH keys only

  # Enable the Cockpit web UI.
  services.cockpit.enable = true;

  # Enable Tailscale
  services.tailscale.enable = true;
  # To connect to Tailscale, run: sudo tailscale up
  # You'll get a URL to authenticate with your Tailscale account

  # Enable Docker
  virtualisation.docker.enable = true;
  virtualisation.docker.enableOnBoot = true;
  virtualisation.docker.daemon.settings = {
    # Optional: Configure Docker daemon settings
    # log-driver = "json-file";
    # log-opts = {
    #   max-size = "10m";
    #   max-file = "3";
    # };
  };

  # Enable Podman
  virtualisation.podman.enable = true;
  # Note: dockerSocket.enable conflicts with Docker, so we'll use Docker as primary
  virtualisation.podman.defaultNetwork.settings.dns_enabled = true;

  # Enable quadlet-nix for declarative container management
  virtualisation.quadlet.enable = true;
  virtualisation.quadlet.autoEscape = true;

  # Enable passwordless sudo for wheel group members (prevents lockout)
  security.sudo.wheelNeedsPassword = false;

  # Define root user with SSH key access (for nixos-anywhere and emergency access)
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDsHOYNAog8L5SAhKp551g4oJFSi/GB+Fg38mmBLhwbrCUSfVSFqKeaOuRlLCQVnTWPZYfyp6cTibHBeigky6fjKhQgKnUJgwPdHjxhSvk7m6zgGj71s45bFT918E1J8hysN2wrijoo6oJ1zSeX3FIWOcFZVR4MHxCdYCMr+4mJp8tb1oQRea6GxCFGCms7DoNii+gWL/K2KZTMHKZ6l9Nf5CXq/6+a9Pfog3XuRlpTxLlIVj8YMC8TeRki0m9mG4+gk4OtCzACL/ngY0OxRWN4IN0NhFZOO5FHwytMR9/yNiAzafzaIt2szd69nmPG3DrXSUN1nXZKR78kM5O1kIaEKNeWJjhTXuDF7DtMF61TlXDWmsFxQbF9TAWK7nXJMUzAgXY1vIkTiYV3uwBB9upyKmXD/M5U1cFDvY6sSnINHxaqXp7/IoEHsXzHKmR5yhGLVszMzMlINBTxrWEYbjzNJPEvWeLCt3EbU4LPVffc8MA+l9zujSDjMO78uC7k/Ek= chadrussell@Chads-MacBook-Pro.local"
  ];

  # Define your user account.
  users.users.crussell = {
    isNormalUser = true;
    # Add user to the 'wheel' group to grant sudo privileges.
    extraGroups = [ "wheel" "docker" ];
    # CRITICAL: Add your SSH public key here to ensure you can log in.
    openssh.authorizedKeys.keys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDsHOYNAog8L5SAhKp551g4oJFSi/GB+Fg38mmBLhwbrCUSfVSFqKeaOuRlLCQVnTWPZYfyp6cTibHBeigky6fjKhQgKnUJgwPdHjxhSvk7m6zgGj71s45bFT918E1J8hysN2wrijoo6oJ1zSeX3FIWOcFZVR4MHxCdYCMr+4mJp8tb1oQRea6GxCFGCms7DoNii+gWL/K2KZTMHKZ6l9Nf5CXq/6+a9Pfog3XuRlpTxLlIVj8YMC8TeRki0m9mG4+gk4OtCzACL/ngY0OxRWN4IN0NhFZOO5FHwytMR9/yNiAzafzaIt2szd69nmPG3DrXSUN1nXZKR78kM5O1kIaEKNeWJjhTXuDF7DtMF61TlXDWmsFxQbF9TAWK7nXJMUzAgXY1vIkTiYV3uwBB9upyKmXD/M5U1cFDvY6sSnINHxaqXp7/IoEHsXzHKmR5yhGLVszMzMlINBTxrWEYbjzNJPEvWeLCt3EbU4LPVffc8MA+l9zujSDjMO78uC7k/Ek= chadrussell@Chads-MacBook-Pro.local"
    ];
    # Enable password login - you need to set a hashed password
    # To generate a hashed password, run: mkpasswd -m SHA-512
    # Then replace the placeholder below with your hashed password
    hashedPassword = "$6$HG8zp6H0V/NAQJbw$CkWKAqc8nU4BdshhBXg9SczhrVNLQqu2tLAozAfgMEfXopUOyo8pdp8k13oQLpiPJqzASjdOj1Bi2fIfnMFjK1";
  };

  # Set your time zone.
  time.timeZone = "America/New_York";

  # Install git package
  environment.systemPackages = with pkgs; [
    git
  ];

  # Network interface optimizations (equivalent to ethtool commands)
  # Disable various offloading features for better performance/stability
  boot.kernelParams = [
    # Disable GSO (Generic Segmentation Offload)
    "net.ifnames=0"
  ];

  # Configure network interface optimizations
  systemd.network.networks."40-eth0" = {
    matchConfig.Name = "eno1";
    networkConfig.DHCP = "no";
    address = [ "192.168.20.62/24" ];
    routes = [
      { routeConfig.Gateway = "192.168.20.1"; }
    ];
    dns = [ "192.168.10.1" "8.8.8.8" ];
  };

  # Apply ethtool optimizations via systemd service
  # This runs once at boot and applies network interface optimizations
  systemd.services.ethtool-optimizations = {
    description = "Apply ethtool optimizations to network interface";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "ethtool-optimizations" ''
        # Wait for interface to be up
        sleep 5
        # Apply ethtool optimizations
        ${pkgs.ethtool}/bin/ethtool -K eno1 gso off gro off tso off tx off rx off rxvlan off txvlan off sg off
      '';
      RemainAfterExit = true;
    };
  };

  # Enable experimental Nix features
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # This is required by NixOS.
  system.stateVersion = "25.05";
}
