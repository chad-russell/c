{ includeBootConfig ? false, sops-nix }: { pkgs, config, lib, ... }: {
    imports = [ sops-nix.nixosModules.sops ];
    
    networking.hostName = "vm-gateway";
    networking.firewall.allowedTCPPorts = [ 80 443 22 3000 8080 ];
    networking.firewall.allowedUDPPorts = [ 53 ];
    networking.useDHCP = false;
    networking.defaultGateway = "192.168.1.1";
    networking.nameservers = [ "1.1.1.1" "8.8.8.8" ];

    networking.interfaces.ens18 = {
        ipv4.addresses = [{
            address = "192.168.1.201";
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

    services.resolved.enable = false;

    # Install Tailscale
    services.tailscale.enable = true;

    # Example script that uses the OAuth credentials
    environment.systemPackages = [
        pkgs.git 
        pkgs.tailscale
        pkgs.curl
        pkgs.jq
        (pkgs.writeShellScriptBin "tailscale-api-test" ''
        #!/bin/bash
        # Example script showing how to use the SOPS secrets
        CLIENT_ID=$(cat ${config.sops.secrets.tailscale-oauth-client-id.path})
        CLIENT_SECRET=$(cat ${config.sops.secrets.tailscale-oauth-client-secret.path})
        
        echo "Testing Tailscale API access..."
        echo "Client ID: $CLIENT_ID"
        echo "Client Secret: [REDACTED]"
        
        # Example API call to get tailnet info
        ${pkgs.curl}/bin/curl -u "$CLIENT_ID:$CLIENT_SECRET" \
            "https://api.tailscale.com/api/v2/tailnet/-/devices"
        '')
    ];

    services.adguardhome = {
        enable = true;
        settings = {
        http.address = "0.0.0.0:3000";
        dns = {
            bind_hosts = [ "0.0.0.0" ];
            port = 53;
            upstream_dns = [
            "1.1.1.1"
            "8.8.8.8"
            ];
        };
        filtering = {
            enabled = true;
            rewrites = [
            { domain = "*.internal.crussell.io"; answer = "192.168.1.201"; }
            { domain = "*.crussell.io"; answer = "192.168.1.201"; }
            ];
        };
        };
    };

    services.traefik = {
        enable = true;
        staticConfigOptions = {
        entryPoints = {
            web = {
                address = ":80";
                proxyProtocol = {
                    trustedIPs = [ "100.74.176.46" ]; # Tailscale IP of cloud-proxy
                };
                http.redirections = {
                    entryPoint = {
                        to = "websecure";
                        scheme = "https";
                        permanent = true;
                    };
                };
            };
            websecure = {
                address = ":443";
                proxyProtocol = {
                    trustedIPs = [ "100.74.176.46" ]; # Tailscale IP of cloud-proxy
                };
                http.tls = {
                    certResolver = "letsencrypt";
                    domains = [
                        { main = "crussell.io"; sans = ["*.crussell.io"]; }
                        { main = "internal.crussell.io"; sans = ["*.internal.crussell.io"]; }
                    ];
                };
            };
        };
        api = {
            dashboard = true;
        };
        certificatesResolvers.letsencrypt.acme = {
            storage = "/var/lib/traefik/acme.json";
            caServer = "https://acme-v02.api.letsencrypt.org/directory";
            dnsChallenge = {
                provider = "route53";
                delayBeforeCheck = 240;
                resolvers = [ "1.1.1.1:53" "8.8.8.8:53" ];
            };
        };
        log.level = "DEBUG";
        };
        dynamicConfigOptions = {
        http = {
            middlewares = {
            "traefik-dashboard-auth" = {
                basicAuth.users = [
                "crussell:$apr1$yjZbgjgW$5elC5.hoQDRIg5Y.yyAaR."
                ];
            };
            };
            routers = {
                # --- Routers for *.internal.crussell.io (Primarily LAN access) ---
                "traefik-dashboard-internal" = {
                    rule = "Host(`traefik.internal.crussell.io`)";
                    service = "api@internal"; # Special service for Traefik API/dashboard
                    entryPoints = [ "web" "websecure" ]; 
                    middlewares = [ "traefik-dashboard-auth" ];
                    # TLS will be handled by the websecure entrypoint's global TLS config
                };

                "test-internal" = {
                    rule = "Host(`test.internal.crussell.io`)";
                    service = "test-svc";
                    entryPoints = [ "websecure" ];
                };

                "jellyseer-internal" = {
                    rule = "Host(`jellyseer.internal.crussell.io`)";
                    service = "jellyseer-svc";
                    entryPoints = [ "websecure" ];
                };

                "homeassistant-public" = {
                    rule = "Host(`homeassistant.crussell.io`)";
                    service = "homeassistant-svc";
                    entryPoints = [ "websecure" ];
                };

                "mealie-public" = {
                    rule = "Host(`mealie.crussell.io`)";
                    service = "mealie-svc";
                    entryPoints = [ "websecure" ];
                };

                "jellyfin-public" = {
                    rule = "Host(`jellyfin.crussell.io`)";
                    service = "jellyfin-svc";
                    entryPoints = [ "websecure" ];
                };

                "root-domain-public" = {
                    rule = "Host(`crussell.io`)";
                    service = "homeassistant-svc";
                    entryPoints = [ "websecure" ];
                };
            };

            services = {
                "test-svc" = { loadBalancer.servers = [{ url = "http://192.168.1.202:80"; }]; };
                "mealie-svc" = { loadBalancer.servers = [{ url = "http://192.168.1.202:9925"; }]; };
                "homeassistant-svc" = { loadBalancer.servers = [{ url = "http://192.168.1.51:8123"; }]; };
                "jellyfin-svc" = { loadBalancer.servers = [{ url = "http://192.168.1.203:8096"; }]; };
                "jellyseer-svc" = { loadBalancer.servers = [{ url = "http://192.168.1.203:5055"; }]; };
            };
        };
        };
    };

    # Configure Traefik with AWS credentials for Route53
    systemd.services.traefik = {
        environment = {
            AWS_REGION = "us-east-1";
        };
        serviceConfig = {
            EnvironmentFile = config.sops.templates."traefik-env".path;
        };
    };

    # Create template for Traefik environment file
    sops.templates."traefik-env" = {
        content = ''
        AWS_REGION=us-east-1
        AWS_ACCESS_KEY_ID=${config.sops.placeholder.aws-access-key-id}
        AWS_SECRET_ACCESS_KEY=${config.sops.placeholder.aws-secret-access-key}
        LETSENCRYPT_EMAIL=${config.sops.placeholder.letsencrypt-email}
        AWS_HOSTED_ZONE_ID=${config.sops.placeholder.aws-hosted-zone-id}
        '';
        owner = "root";
        group = "root";
        mode = "0444";
    };

    systemd.tmpfiles.rules = [
        "d /var/lib/traefik 0755 traefik traefik -"
        "f /var/lib/traefik/acme.json 0600 traefik traefik -"
        # "f /var/lib/traefik/dynamic-config.yaml 0600 traefik traefik -" # We use sops-nix for this now
        "d /etc/sops 0755 root root -"
        "d /etc/sops/age 0755 root root -"
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
    sops = {
        defaultSopsFile = ../secrets.yaml;
        defaultSopsFormat = "yaml";
        age.keyFile = "/etc/sops/age/keys.txt";
        
        secrets = {
        tailscale-oauth-client-id = {
            owner = "root";
            group = "root";
            mode = "0400";
        };
        tailscale-oauth-client-secret = {
            owner = "root";
            group = "root";
            mode = "0400";
        };
        aws-access-key-id = {
            owner = "traefik";
            group = "traefik";
            mode = "0400";
        };
        aws-secret-access-key = {
            owner = "traefik";
            group = "traefik";
            mode = "0400";
        };
        letsencrypt-email = {
            owner = "traefik";
            group = "traefik";
            mode = "0400";
        };
        aws-hosted-zone-id = { # Add if you want to manage via SOPS
            owner = "traefik";
            group = "traefik";
            mode = "0400";
        };
        };
    };
}