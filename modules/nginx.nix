{ includeBootConfig ? false }: { pkgs, lib, sops-nix, self, ... }: {
    networking.hostName = "vm-test";
    networking.firewall.allowedTCPPorts = [ 22 80 9925 ];
    networking.useDHCP = false;
    networking.defaultGateway = "192.168.1.1";
    networking.nameservers = [ "1.1.1.1" "8.8.8.8" ];

    networking.interfaces.ens18 = {
        ipv4.addresses = [{
        address = "192.168.1.202";
        prefixLength = 24;
        }];
    };

    # Boot and filesystem configuration - only included for nixosSystem builds
    fileSystems."/" = lib.mkIf includeBootConfig {
        device = "/dev/vda1";
        fsType = "ext4";
    };

    boot = lib.mkIf includeBootConfig {
        loader.grub.enable = true;
        loader.grub.devices = [ "/dev/vda" ];
        initrd.availableKernelModules = [ "uhci_hcd" "ehci_pci" "ahci" "sd_mod" ];
        initrd.kernelModules = [ "virtio_pci" "virtio_ring" "virtio_blk" ];
        kernel.sysctl = {
        "net.ipv6.conf.all.disable_ipv6" = "1";
        "net.ipv6.conf.default.disable_ipv6" = "1";
        };
    };

    services.openssh.enable = true;
    services.openssh.settings = {
        PermitRootLogin = "yes";
        PasswordAuthentication = true;
    };

    # Enable Podman
    virtualisation = {
        podman = {
        enable = true;
        dockerCompat = true;  # For docker-compose compatibility
        };
    };

    # Create Mealie data directory
    systemd.tmpfiles.rules = [
        "d /var/lib/mealie 0755 root root -"
    ];

    # Mealie container service
    systemd.services.mealie = {
        description = "Mealie Recipe Manager";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        
        serviceConfig = {
        Type = "simple";
        ExecStartPre = [
            "-${pkgs.podman}/bin/podman rm -f mealie"
            "${pkgs.podman}/bin/podman pull ghcr.io/mealie-recipes/mealie:v2.8.0"
        ];
        ExecStart = ''
            ${pkgs.podman}/bin/podman run --name mealie \
            --rm \
            -p 9925:9000 \
            -e ALLOW_SIGNUP=false \
            -e PUID=1000 \
            -e PGID=1000 \
            -e TZ=America/New_York \
            -e BASE_URL=http://mealie.internal.crussell.io \
            -v /var/lib/mealie:/app/data \
            --memory=1000M \
            ghcr.io/mealie-recipes/mealie:v2.8.0
        '';
        ExecStop = "${pkgs.podman}/bin/podman stop mealie";
        Restart = "always";
        RestartSec = "10s";
        };
    };

    # Configure Nginx as reverse proxy for Mealie
    services.nginx = {
        enable = true;
        
        # Recommended Nginx settings
        recommendedGzipSettings = true;
        recommendedOptimisation = true;
        recommendedProxySettings = true;
        recommendedTlsSettings = true;

        virtualHosts = {
        "mealie.internal.crussell.io" = {
            locations."/" = {
            proxyPass = "http://127.0.0.1:9925";
            proxyWebsockets = true;
            extraConfig = ''
                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto $scheme;
            '';
            };
        };
        "default" = {
            root = "/var/www";
            listen = [
            { addr = "0.0.0.0"; port = 80; }
            ];
            default = true;
        };
        };
    };

    environment.systemPackages = with pkgs; [
        git 
        curl
        podman
        podman-compose
    ];

    users.users.crussell = {
        isNormalUser = true;
        extraGroups = [ "wheel" ];
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

    nix.extraOptions = ''
        experimental-features = nix-command flakes
    '';

    system.stateVersion = "25.05";
}