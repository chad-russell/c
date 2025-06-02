{ includeBootConfig ? false }: { pkgs, lib, ... }: {
    networking.hostName = "vm-jellyfin";
    networking.firewall.allowedTCPPorts = [ 22 8096 5055 ];
    networking.useDHCP = false;
    networking.defaultGateway = "192.168.1.1";
    networking.nameservers = [ "1.1.1.1" "8.8.8.8" ];

    networking.interfaces.ens18 = {
        ipv4.addresses = [{
            address = "192.168.1.203";
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

    # Create data directories
    systemd.tmpfiles.rules = [
        "d /var/lib/jellyfin 0755 root root -"
        "d /var/lib/jellyseer 0755 root root -"
        "d /media 0755 root root -"
        "d /media/movies 0755 root root -"
        "d /media/tv 0755 root root -"
        "d /media/music 0755 root root -"
    ];

    # Jellyfin container service
    systemd.services.jellyfin = {
        description = "Jellyfin Media Server";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        
        serviceConfig = {
        Type = "simple";
        ExecStartPre = [
            "-${pkgs.podman}/bin/podman rm -f jellyfin"
            "${pkgs.podman}/bin/podman pull docker.io/jellyfin/jellyfin:latest"
        ];
        ExecStart = ''
            ${pkgs.podman}/bin/podman run --name jellyfin \
            --rm \
            -p 8096:8096 \
            -e PUID=1000 \
            -e PGID=1000 \
            -e TZ=America/New_York \
            -v /var/lib/jellyfin:/config \
            -v /media:/media \
            --device /dev/dri:/dev/dri \
            --memory=2000M \
            docker.io/jellyfin/jellyfin:latest
        '';
        ExecStop = "${pkgs.podman}/bin/podman stop jellyfin";
        Restart = "always";
        RestartSec = "10s";
        };
    };

    # Jellyseer container service
    systemd.services.jellyseer = {
        description = "Jellyseer Request Management";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" "jellyfin.service" ];
        
        serviceConfig = {
            Type = "simple";
            ExecStartPre = [
                "-${pkgs.podman}/bin/podman rm -f jellyseer"
                "${pkgs.podman}/bin/podman pull docker.io/fallenbagel/jellyseerr:latest"
            ];
            ExecStart = ''
                ${pkgs.podman}/bin/podman run --name jellyseer \
                --rm \
                -p 5055:5055 \
                -e LOG_LEVEL=debug \
                -e TZ=America/New_York \
                -v /var/lib/jellyseer:/app/config \
                --memory=500M \
                docker.io/fallenbagel/jellyseerr:latest
            '';
            ExecStop = "${pkgs.podman}/bin/podman stop jellyseer";
            Restart = "always";
            RestartSec = "10s";
        };
    };

    environment.systemPackages = with pkgs; [
        git 
        curl
        podman
        podman-compose
        ffmpeg
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