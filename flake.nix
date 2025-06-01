{
  description = "Home Compute Cluster -- test node 1";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixos-generators.url = "github:nix-community/nixos-generators";
    sops-nix.url = "github:Mic92/sops-nix";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    nixos-anywhere.url = "github:nix-community/nixos-anywhere";
    nixos-anywhere.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nixos-generators, sops-nix, disko, nixos-anywhere, ... }:
    let
      system = "x86_64-linux";

      makeNginxModule = { includeBootConfig ? false }: { pkgs, lib, ... }: {
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

        users.users.root = {
          password = "password";
        };

        nix.extraOptions = ''
          experimental-features = nix-command flakes
        '';

        system.stateVersion = "25.05";
      };

      makeGatewayModule = { includeBootConfig ? false }: { pkgs, config, lib, ... }: {
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
              insecure = true; # TODO(chad): Consider securing this, e.g., behind auth or specific hostname
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
              routers = {
                # --- Routers for *.internal.crussell.io (Primarily LAN access) ---
                "traefik-dashboard-internal" = {
                  rule = "Host(`traefik.internal.crussell.io`)";
                  service = "api@internal"; # Special service for Traefik API/dashboard
                  entryPoints = [ "web" "websecure" ]; 
                  # TLS will be handled by the websecure entrypoint's global TLS config
                };
                "test-internal" = {
                  rule = "Host(`test.internal.crussell.io`)";
                  service = "test-svc";
                  entryPoints = [ "websecure" ];
                };

                "homeassistant-public" = {
                  rule = "Host(`homeassistant.crussell.io`) || Host(`hetzner-homeassistant.crussell.io`)";
                  service = "homeassistant-svc";
                  entryPoints = [ "websecure" ];
                };

                "mealie-public" = {
                  rule = "Host(`mealie.crussell.io`) || Host(`hetzner-mealie.crussell.io`)";
                  service = "mealie-svc";
                  entryPoints = [ "websecure" ];
                };

                "ssltesthost-public" = {
                  rule = "Host(`ssltest.crussell.io`)";
                  service = "test-svc";
                  entryPoints = [ "websecure" ];
                };

                "root-domain-public" = {
                  rule = "Host(`crussell.io`)";
                  service = "homeassistant-svc";
                  entryPoints = [ "websecure" ];
                };
              };

              services = {
                "test-svc" = { loadBalancer.servers = [{ url = "http://192.168.1.202:80"; }]; }; # Renamed from 'test'
                "mealie-svc" = { loadBalancer.servers = [{ url = "http://192.168.1.202:9925"; }]; };
                "homeassistant-svc" = { loadBalancer.servers = [{ url = "http://192.168.1.51:8123"; }]; };
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

        users.users.root = {
          password = "password";
        };

        nix.extraOptions = ''
          experimental-features = nix-command flakes
        '';

        system.stateVersion = "25.05";

        # SOPS configuration
        sops = {
          defaultSopsFile = ./secrets.yaml;
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
      };

      cloudProxyModule = { pkgs, config, lib, ... }: {
        imports = [ sops-nix.nixosModules.sops ./hetzner-bootstrap/configuration.nix ];
        
        networking.hostName = "cloud-proxy";
        networking.firewall.allowedTCPPorts = [ 80 443 22 ];

        # Use DHCP for cloud deployment
        networking.useDHCP = true;
        networking.nameservers = [ "1.1.1.1" "8.8.8.8" ];

        services.resolved.enable = false;

        # Install Tailscale
        services.tailscale.enable = true;

        # System packages
        environment.systemPackages = with pkgs; [
          git 
          curl
          jq
          tailscale # Ensure tailscale CLI is available
        ];

        fileSystems."/" = {
          device = "/dev/sda2";
          fsType = "ext4";
        };

        boot.loader.grub.devices = [ "/dev/sda" ];

        services.traefik = {
          enable = true;
          staticConfigOptions = {
            entryPoints = {
              web.address = ":80";
              websecure.address = ":443";
            };
            # API and dashboard are removed
            # api = {}; 
            log.level = "INFO";
          };
          dynamicConfigOptions = {
            tcp = {
              routers = {
                "http-forwarder" = {
                  rule = "HostSNI(`*`)";
                  entryPoints = [ "web" ];
                  service = "gateway-http-svc";
                };
                "https-passthrough" = {
                  rule = "HostSNI(`*`)"; 
                  entryPoints = [ "websecure" ];
                  service = "gateway-https-svc";
                  tls.passthrough = true;
                };
              };
              services = {
                "gateway-http-svc" = {
                  loadBalancer.servers = [{ address = "100.67.164.11:80"; }];
                  # PROXY protocol for original client IP
                  loadBalancer.proxyProtocol = { version = 2; };
                };
                "gateway-https-svc" = {
                  loadBalancer.servers = [{ address = "100.67.164.11:443"; }];
                  # PROXY protocol for original client IP
                  loadBalancer.proxyProtocol = { version = 2; };
                };
              };
            };
          };
        };

        # SOPS/AWS related configurations are generally not needed for this simplified proxy.
        systemd.services.traefik = {
          # environment = { AWS_REGION = "us-east-1"; }; # Likely not needed
          # serviceConfig = {}; 
        };

        systemd.tmpfiles.rules = [
          "d /var/lib/traefik 0755 traefik traefik -"
          # No acme.json managed by this Traefik instance
          "d /etc/sops 0755 root root -"
          "d /etc/sops/age 0755 root root -"
        ];

        sops = {
          defaultSopsFile = ./secrets.yaml;
          defaultSopsFormat = "yaml";
          age.keyFile = "/etc/sops/age/keys.txt";
          secrets = {
            # No Traefik-specific secrets needed for cloud-proxy in this setup.
            # Keep tailscale secrets if other scripts on cloud-proxy use them, otherwise can be removed.
             tailscale-oauth-client-id = { 
               # owner = "root"; group = "root"; mode = "0400"; # Example, if used by other tools
             };
             tailscale-oauth-client-secret = {
               # owner = "root"; group = "root"; mode = "0400"; # Example, if used by other tools
             };
          };
        };
      };

    in {
      packages.${system} = {
        nginx = nixos-generators.nixosGenerate {
          inherit system;
          format = "proxmox";
          modules = [ (makeNginxModule { }) ];
        };

        gateway = nixos-generators.nixosGenerate {
          inherit system;
          format = "proxmox";
          modules = [ (makeGatewayModule { }) ];
        };

        # Helper script for deploying the age key
        deploy-key = nixpkgs.legacyPackages.${system}.writeShellScriptBin "deploy-age-key" ''
          #!/bin/bash
          set -e
          
          if [ $# -eq 0 ]; then
            echo "Usage: $0 <VM_IP_ADDRESS>"
            echo "Example: $0 178.156.171.212"
            exit 1
          fi
          
          VM_IP="$1"
          KEY_FILE="age-key.txt"
          
          if [ ! -f "$KEY_FILE" ]; then
            echo "Error: $KEY_FILE not found in current directory"
            exit 1
          fi
          
          echo "Deploying age key to VM at $VM_IP..."
          scp "$KEY_FILE" "$VM_IP:/tmp/"
          ssh "$VM_IP" "mv /tmp/$KEY_FILE /etc/sops/age/keys.txt && chmod 600 /etc/sops/age/keys.txt"
          echo "Age key deployed successfully!"
          
          echo "Testing secrets access..."
          ssh "$VM_IP" "tailscale-api-test"
        '';

        # nixos-anywhere CLI tool
        nixos-anywhere = nixos-anywhere.packages.${system}.default;
      };

      nixosConfigurations = {
        gateway = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [ (makeGatewayModule { includeBootConfig = true; }) ];
        };

        nginx = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [ (makeNginxModule { includeBootConfig = true; }) ];
        };

        # NixOS configuration for Hetzner VPS (used by nixos-anywhere)
        hetzner-bootstrap = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";

          modules = [
            ./hetzner-bootstrap/configuration.nix
            ./hetzner-bootstrap/disko-config.nix
            disko.nixosModules.disko
          ];
        };

        # Minimal cloud reverse proxy for Hetzner
        cloud-proxy = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [ cloudProxyModule ];
        };
      };
    };
}