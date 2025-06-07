{ sops-nix }: { pkgs, config, lib, ... }: {
  imports = [
    sops-nix.nixosModules.sops
    ((import ./beszel-agent.nix) { inherit sops-nix pkgs config; })
  ];

  networking.hostName = "vm-miscbox";
  networking.firewall.allowedTCPPorts = [ 22 8000 ];
  networking.useDHCP = false;
  networking.defaultGateway = "192.168.20.1";
  networking.nameservers = [ "1.1.1.1" "8.8.8.8" ];

  networking.interfaces.ens18 = {
    ipv4.addresses = [{
      address = "192.168.20.205";
      prefixLength = 24;
    }];
  };

  fileSystems."/" = {
    device = "/dev/vda1";
    fsType = "ext4";
  };

  # Persistent storage for Paperless-ngx
  fileSystems."/var/lib/paperless" = {
    device = "/var/lib/paperless";
    fsType = "none";
    options = [ "bind" ];
  };

  boot = {
    loader.grub.enable = true;
    loader.grub.devices = [ "/dev/vda" ];
    initrd.availableKernelModules = [ "uhci_hcd" "ehci_pci" "ahci" "sd_mod" ];
    initrd.kernelModules = [ "virtio_pci" "virtio_ring" "virtio_blk" ];
  };

  services.openssh.enable = true;
  services.openssh.settings = {
    PermitRootLogin = "yes";
    PasswordAuthentication = true;
  };

  services.paperless = {
    enable = true;
    database.createLocally = true;
    environmentFile = config.sops.templates."paperless-db-pass".path;
    settings = {
        PAPERLESS_URL = "https://paperless.internal.crussell.io";
        PAPERLESS_TIME_ZONE = "America/New_York";
        PAPERLESS_OCR_LANGUAGE = "eng";
    };
    exporter.enable = true;
    configureTika = true;
    address = "0.0.0.0";
  };

  environment.systemPackages = with pkgs; [
    git
    curl
    podman
    podman-compose
    htop
  ];

  users.users.crussell = {
    isNormalUser = true;
    uid = 1000;
    extraGroups = [ "wheel" "users" ];
    initialHashedPassword = "$y$j9T$bh0qHa7NdcwmdzYc8CjQj.$HUOFYiehqVxeTXtkFs2fAQZuohSp8uvonYB1Bbkf567";
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDsHOYNAog8L5SAhKp551g4oJFSi/GB+Fg38mmBLhwbrCUSfVSFqKeaOuRlLCQVnTWPZYfyp6cTibHBeigky6fjKhQgKnUJgwPdHjxhSvk7m6zgGj71s45bFT918E1J8hysN2wrijoo6oJ1zSeX3FIWOcFZVR4MHxCdYCMr+4mJp8tb1oQRea6GxCFGCms7DoNii+gWL/K2KZTMHKZ6l9Nf5CXq/6+a9Pfog3XuRlpTxLlIVj8YMC8TeRki0m9mG4+gk4OtCzACL/ngY0OxRWN4IN0NhFZOO5FHwytMR9/yNiAzafzaIt2szd69nmPG3DrXSUN1nXZKR78kM5O1kIaEKNeWJjhTXuDF7DtMF61TlXDWmsFxQbF9TAWK7nXJMUzAgXY1vIkTiYV3uwBB9upyKmXD/M5U1cFDvY6sSnINHxaqXp7/IoEHsXzHKmR5yhGLVszMzMlINBTxrWEYbjzNJPEvWeLCt3EbU4LPVffc8MA+l9zujSDjMO78uC7k/Ek= chadrussell@Chads-MacBook-Pro.local"
    ];
  };

  users.users.root = {
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDsHOYNAog8L5SAhKp551g4oJFSi/GB+Fg38mmBLhwbrCUSfVSFqKeaOuRlLCQVnTWPZYfyp6cTibHBeigky6fjKhQgKnUJgwPdHjxhSvk7m6zgGj71s45bFT918E1J8hysN2wrijoo6oJ1zSeX3FIWOcFZVR4MHxCdYCMr+4mJp8tb1oQRea6GxCFGCms7DoNii+gWL/K2KZTMHKZ6l9Nf5CXq/6+a9Pfog3XuRlpTxLlIVj8YMC8TeRki0m9mG4+gk4OtCzACL/ngY0OxRWN4IN0NhFZOO5FHwytMR9/yNiAzafzaIt2szd69nmPG3DrXSUN1nXZKR78kM5O1kIaEKNeWJjhTXuDF7DtMF61TlXDWmsFxQbF9TAWK7nXJMUzAgXY1vIkTiYV3uwBB9upyKmXD/M5U1cFDvY6sSnINHxaqXp7/IoEHsXzHKmR5yhGLVszMzMlINBTxrWEYbjzNJPEvWeLCt3EbU4LPVffc8MA+l9zujSDjMO78uC7k/Ek= chadrussell@Chads-MacBook-Pro.local"
    ];
  };

  users.groups.users = {};

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "25.05";

  # SOPS secrets for Paperless-ngx
  sops.secrets.paperless-secret-key = {
    owner = "root";
    group = "root";
    mode = "0400";
  };
  sops.secrets.paperless-db-pass = {
    owner = "root";
    group = "root";
    mode = "0400";
  };

  # SOPS template for Paperless-ngx env file
  sops.templates."paperless-ngx-env" = {
    content = ''
      PAPERLESS_SECRET_KEY=${config.sops.placeholder.paperless-secret-key}
      PAPERLESS_DBPASS=${config.sops.placeholder.paperless-db-pass}
    '';
    owner = "root";
    group = "root";
    mode = "0444";
  };
} 