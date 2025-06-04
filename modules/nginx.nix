{ sops-nix }: { pkgs, lib, config, ... }: {
    imports = [ sops-nix.nixosModules.sops ];

    networking.hostName = "vm-test";
    networking.firewall.allowedTCPPorts = [ 22 80 9925 ];
    networking.useDHCP = false;
    networking.defaultGateway = "192.168.1.1";
    networking.nameservers = [ "192.168.1.201" ];

    networking.interfaces.ens18 = {
        ipv4.addresses = [{
            address = "192.168.1.202";
            prefixLength = 24;
        }];
    };

    # Boot and filesystem configuration
    fileSystems."/" = {
        device = "/dev/vda1";
        fsType = "ext4";
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

    # Enable Podman
    virtualisation = {
        podman = {
            enable = true;
            dockerCompat = true;  # For docker-compose compatibility
        };
        oci-containers = {
            backend = "podman";
            containers = {
                mealie = {
                    image = "ghcr.io/mealie-recipes/mealie:v2.8.0";
                    autoStart = true;
                    ports = [ "9925:9000" ];
                    environment = {
                        ALLOW_SIGNUP = "false";
                        PUID = "1000";
                        PGID = "1000";
                        TZ = "America/New_York";
                        BASE_URL = "http://mealie.internal.crussell.io";
                    };
                    volumes = [
                        "/var/lib/mealie:/app/data"
                    ];
                    extraOptions = [
                        "--memory=1000M"
                    ];
                };

                beszel = {
                    image = "henrygd/beszel:latest";
                    autoStart = true;
                    ports = [ "8090:8090" ];
                    volumes = [
                        "/var/lib/beszel_data:/beszel_data"
                        "/var/lib/beszel_socket:/beszel_socket"
                    ];
                };

                beszel-agent = {
                    image = "henrygd/beszel-agent:latest";
                    autoStart = true;
                    volumes = [
                        "/var/lib/beszel_socket:/beszel_socket"
                        "/var/run/docker.sock:/var/run/docker.sock:ro"
                    ];
                    environment = {
                        LISTEN = "/beszel_socket/beszel.sock";
                    };
                    environmentFiles = [ config.sops.templates."beszel-agent-env".path ];
                    extraOptions = [
                        "--network=host"
                    ];
                };
            };
        };
    };

    # Create Mealie data directory
    systemd.tmpfiles.rules = [
        "d /var/lib/mealie 0755 root root -"
        "d /var/lib/beszel_data 0755 root root -"
        "d /var/lib/beszel_socket 0755 root root -"
    ];

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

    nix.settings.experimental-features = [ "nix-command" "flakes" ];

    system.stateVersion = "25.05";

    # SOPS configuration
    sops.defaultSopsFile = ../secrets.yaml;
    sops.defaultSopsFormat = "yaml";
    sops.age.keyFile = "/etc/sops/age/keys.txt";

    # SOPS secret for beszel-agent key
    sops.secrets.beszel-agent-key = {
        owner = "root";
        group = "root";
        mode = "0400";
    };

    # SOPS template for beszel-agent env file
    sops.templates."beszel-agent-env" = {
        content = ''
            KEY=${config.sops.placeholder.beszel-agent-key}
        '';
        owner = "root";
        group = "root";
        mode = "0444";
    };
}