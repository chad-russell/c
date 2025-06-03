{ config, pkgs, lib, ... }: {
    networking.hostName = "vm-jellyfin";
    networking.firewall.allowedTCPPorts = [ 22 8096 5055 ];
    networking.useDHCP = false;
    networking.defaultGateway = "192.168.1.1";
    networking.nameservers = [ "1.1.1.1" "8.8.8.8" ];

    # More flexible network interface configuration that works with both i440fx and q35
    networking.interfaces = {
        ens18.ipv4.addresses = [{
            address = "192.168.1.203";
            prefixLength = 24;
        }];
        # Fallback for q35 machine type which might use different interface names
        enp0s18.ipv4.addresses = [{
            address = "192.168.1.203";
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
        # More flexible kernel module loading
        initrd.availableKernelModules = [ "uhci_hcd" "ehci_pci" "ahci" "sd_mod" "virtio_pci" "virtio_blk" ];
        initrd.kernelModules = [ "virtio_pci" "virtio_ring" "virtio_blk" ];
        kernel.sysctl = {
            "net.ipv6.conf.all.disable_ipv6" = "1";
            "net.ipv6.conf.default.disable_ipv6" = "1";
        };
        
        # Intel GPU kernel modules for hardware acceleration
        kernelModules = [ "i915" ];
    };

    # Enable all firmware for proper Intel GPU support (especially important for newer CPUs)
    hardware.enableAllFirmware = true;

    # Allow unfree packages for Intel GPU firmware
    nixpkgs.config.allowUnfree = true;

    # Hardware acceleration support - following NixOS wiki recommendations
    nixpkgs.config.packageOverrides = pkgs: {
        intel-vaapi-driver = pkgs.intel-vaapi-driver.override { enableHybridCodec = true; };
    };

    # Set VAAPI driver environment variables
    systemd.services.jellyfin.environment.LIBVA_DRIVER_NAME = "iHD"; # For intel-media-driver
    environment.sessionVariables = { LIBVA_DRIVER_NAME = "iHD"; };

    hardware.graphics = {
        enable = true;
        enable32Bit = true;
        extraPackages = with pkgs; [
            intel-media-driver      # For Broadwell (2014) or newer processors. LIBVA_DRIVER_NAME=iHD
            intel-vaapi-driver      # For older processors. LIBVA_DRIVER_NAME=i965
            libva-vdpau-driver      # Previously vaapiVdpau
            intel-compute-runtime-legacy1 # OpenCL support for intel CPUs before 12th gen (i5-9500T is 9th gen)
            # intel-compute-runtime
            vpl-gpu-rt             # QSV on 11th gen or newer
            intel-media-sdk        # QSV up to 11th gen
            intel-ocl              # OpenCL support
        ];
    };

    # SSH configuration
    services.openssh.enable = true;
    services.openssh.settings = {
        PermitRootLogin = "yes";
        PasswordAuthentication = true;
    };

    # Native Jellyfin service
    services.jellyfin = {
        enable = true;
        openFirewall = true;
        user = "crussell";  # Run as our user to access media files easily
    };

    # Native Jellyseerr service
    services.jellyseerr = {
        enable = true;
        openFirewall = true;
    };

    # Create media directories
    systemd.tmpfiles.rules = [
        "d /var/lib/jellyfin 0755 crussell users -"
        "d /media 0755 crussell users -"
        "d /media/movies 0755 crussell users -"
        "d /media/tv 0755 crussell users -"
        "d /media/music 0755 crussell users -"
    ];

    # Add users to video group for GPU access
    users.groups.video = {};

    # Essential packages including jellyfin packages and debugging tools
    environment.systemPackages = with pkgs; [
        git 
        curl
        # Jellyfin packages
        jellyfin
        jellyfin-web
        jellyfin-ffmpeg
        # GPU debugging tools
        intel-gpu-tools
        clinfo          # Check OpenCL support: clinfo  
        libva-utils     # VAAPI utilities (includes vainfo command)
    ];

    users.users.crussell = {
        isNormalUser = true;
        extraGroups = [ "wheel" "video" "jellyfin" ];  # Added jellyfin group
        initialHashedPassword = "$y$j9T$bh0qHa7NdcwmdzYc8CjQj.$HUOFYiehqVxeTXtkFs2fAQZuohSp8uvonYB1Bbkf567";
        openssh.authorizedKeys.keys = [
            "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDsHOYNAog8L5SAhKp551g4oJFSi/GB+Fg38mmBLhwbrCUSfVSFqKeaOuRlLCQVnTWPZYfyp6cTibHBeigky6fjKhQgKnUJgwPdHjxhSvk7m6zgGj71s45bFT918E1J8hysN2wrijoo6oJ1zSeX3FIWOcFZVR4MHxCdYCMr+4mJp8tb1oQRea6GxCFGCms7DoNii+gWL/K2KZTMHKZ6l9Nf5CXq/6+a9Pfog3XuRlpTxLlIVj8YMC8TeRki0m9mG4+gk4OtCzACL/ngY0OxRWN4IN0NhFZOO5FHwytMR9/yNiAzafzaIt2szd69nmPG3DrXSUN1nXZKR78kM5O1kIaEKNeWJjhTXuDF7DtMF61TlXDWmsFxQbF9TAWK7nXJMUzAgXY1vIkTiYV8MA+l9zujSDjMO78uC7k/Ek= chadrussell@Chads-MacBook-Pro.local"
        ];
    };

    users.users.root = {
        openssh.authorizedKeys.keys = [
            "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDsHOYNAog8L5SAhKp551g4oJFSi/GB+Fg38mmBLhwbrCUSfVSFqKeaOuRlLCQVnTWPZYfyp6cTibHBeigky6fjKhQgKnUJgwPdHjxhSvk7m6zgGj71s45bFT918E1J8hysN2wrijoo6oJ1zSeX3FIWOcFZVR4MHxCdYCMr+4mJp8tb1oQRea6GxCFGCms7DoNii+gWL/K2KZTMHKZ6l9Nf5CXq/6+a9Pfog3XuRlpTxLlIVj8YMC8TeRki0m9mG4+gk4OtCzACL/ngY0OxRWN4IN0NhFZOO5FHwytMR9/yNiAzafzaIt2szd69nmPG3DrXSUN1nXZKR78kM5O1kIaEKNeWJjhTXuDF7DtMF61TlXDWmsFxQbF9TAWK7nXJMUzAgXY1vIkTiYV3uwBB9upyKmXD/M5U1cFDvY6sSnINHxaqXp7/IoEHsXzHKmR5yhGLVszMzMlINBTxrWEYbjzNJPEvWeLCt3EbU4LPVffc8MA+l9zujSDjMO78uC7k/Ek= chadrussell@Chads-MacBook-Pro.local"
        ];
    };

    nix.settings.experimental-features = [ "nix-command" "flakes" ];

    system.stateVersion = "25.05";
} 