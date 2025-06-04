{ pkgs, config, lib, ... }: {
    networking.hostName = "vm-cloak";
    networking.firewall.allowedTCPPorts = [ 22 8080 ]; # SSH and qBittorrent web UI
    networking.useDHCP = false;

    networking.interfaces.ens18 = {
        ipv4.addresses = [{
            address = "192.168.1.204";
            prefixLength = 24;
        }];
    };

    # Boot and filesystem configuration
    fileSystems."/" = {
        device = "/dev/vda1";
        fsType = "ext4";
    };

    fileSystems."/mnt/media" = {
        device = "192.168.1.55:/mnt/tank/media";
        fsType = "nfs";
        options = [ "x-systemd.automount" "noatime" "nfsvers=4" ];
    };
    
    boot = {
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

    # Enable Tailscale
    services.tailscale = {
        enable = true;
        extraUpFlags = [
            "--accept-routes"
            "--accept-dns=false"
        ];
        extraSetFlags = [
            "--exit-node=100.84.251.68" # Mullvad exit node (Miami, FL)
            "--exit-node-allow-lan-access"
        ];
    };

    # Enable Podman for qBittorrent container
    virtualisation = {
        podman = {
            enable = true;
            dockerCompat = true;  # For docker-compose compatibility
        };
        oci-containers = {
            backend = "podman";
            containers = {
                qbittorrent = {
                    image = "lscr.io/linuxserver/qbittorrent:latest";
                    autoStart = true;
                    ports = [ "8080:8080" ];
                    environment = {
                        PUID = "1000";
                        PGID = "1000";
                        TZ = "America/New_York";
                        WEBUI_PORT = "8080";
                    };
                    volumes = [
                        "/var/lib/qbittorrent/config:/config"
                        "/mnt/media/Downloads:/downloads"
                    ];
                    extraOptions = [
                        "--memory=1000M"
                        "--network=host"  # For VPN compatibility
                    ];
                };
            };
        };
    };

    # Create qBittorrent directories
    systemd.tmpfiles.rules = [
        "d /var/lib/qbittorrent 0755 crussell users -"
        "d /var/lib/qbittorrent/config 0755 crussell users -"
        "d /mnt/media 0775 crussell media -"
        "Z /mnt/media/Downloads 0775 crussell media -"
    ];

    environment.systemPackages = with pkgs; [
        git 
        tailscale
        curl
        htop
        # Useful for VPN troubleshooting
        iptables
        traceroute
        dig
        nfs-utils
    ];

    users.users.crussell = {
        isNormalUser = true;
        extraGroups = [ "wheel" "media" ];
        initialHashedPassword = "$y$j9T$bh0qHa7NdcwmdzYc8CjQj.$HUOFYiehqVxeTXtkFs2fAQZuohSp8uvonYB1Bbkf567";
        openssh.authorizedKeys.keys = [
            "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDsHOYNAog8L5SAhKp551g4oJFSi/GB+Fg38mmBLhwbrCUSfVSFqKeaOuRlLCQVnTWPZYfyp6cTibHBeigky6fjKhQgKnUJgwPdHjxhSvk7m6zgGj71s45bFT918E1J8hysN2wrijoo6oJ1zSeX3FIWOcFZVR4MHxCdYCMr+4mJp8tb1oQRea6GxCFGCms7DoNii+gWL/K2KZTMHKZ6l9Nf5CXq/6+a9Pfog3XuRlpTxLlIVj8YMC8TeRki0m9mG4+gk4OtCzACL/ngY0OxRWN4IN0NhFZOO5FHwytMR9/yNiAzafzaIt2szd69nmPG3DrXSUN1nXZKR78kM5O1kIaEKNeWJjhTXuDF7DtMF61TlXDWmsFxQbF9TAWK7nXJMUzAgXY1vIkTiYV3uwBB9upyKmXD/M5U1cFDvY6sSnINHxaqXp7/IoEHsXzHKmR5yhGLVszMzMlINBTxrWEYbjzNJPEvWeLCt3EbU4LPVffc8MA+l9zujSDjMO78uC7k/Ek= chadrussell@Chads-MacBook-Pro.local"
        ];
    };

    users.users.root = {
        openssh.authorizedKeys.keys = [
            "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDsHOYNAog8L5SAhKp551g4oJFSi/GB+Fg38mmBLhwbrCUSfVSFqKeaOuRlLCQVnTWPZYfyp6cTibHBeigky6fjKhQgKnUJgwPdHjxhSvk7m6zgGj71s45bFT918E1J8hysN2wrijoo6oJ1zSeX3FIWOcFZVR4MHxCdYCMr+4mJp8tb1oQRea6GxCFGCms7DoNii+gWL/K2KZTMHKZ6l9Nf5CXq/6+a9Pfog3XuRlpTxLlIVj8YMC8TeRki0m9mG4+gk4OtCzACL/ngY0OxRWN4IN0NhFlZOO5FHwytMR9/yNiAzafzaIt2szd69nmPG3DrXSUN1nXZKR78kM5O1kIaEKNeWJjhTXuDF7DtMF61TlXDWmsFxQbF9TAWK7nXJMUzAgXY1vIkTiYV3uwBB9upyKmXD/M5U1cFDvY6sSnINHxaqXp7/IoEHsXzHKmR5yhGLVszMzMlINBTxrWEYbjzNJPEvWeLCt3EbU4LPVffc8MA+l9zujSDjMO78uC7k/Ek= chadrussell@Chads-MacBook-Pro.local"
        ];
    };

    users.groups.media = {};

    nix.settings.experimental-features = [ "nix-command" "flakes" ];

    system.stateVersion = "25.05";
} 