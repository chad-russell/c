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
              web.address = ":80";
              websecure.address = ":443";
            };
            api = {
              dashboard = true;
              insecure = true;
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
                test = {
                  rule = "Host(`test.internal.crussell.io`)";
                  service = "test";
                  entryPoints = [ "web" ];
                };
                mealie = {
                  rule = "Host(`mealie.internal.crussell.io`)";
                  service = "mealie-svc";
                  entryPoints = [ "websecure" ];
                  tls.certResolver = "letsencrypt";
                };
                mealie-http-redirect = {
                  rule = "Host(`mealie.internal.crussell.io`)";
                  entryPoints = [ "web" ];
                  middlewares = [ "https-redirect" ];
                  service = "noop@internal";
                };
                homeassistant = {
                  rule = "Host(`homeassistant.crussell.io`)";
                  service = "homeassistant-svc";
                  entryPoints = [ "websecure" ];
                  tls.certResolver = "letsencrypt";
                };
                homeassistant-http-redirect = {
                  rule = "Host(`homeassistant.crussell.io`)";
                  entryPoints = [ "web" ];
                  middlewares = [ "https-redirect" ];
                  service = "noop@internal";
                };
                ssltesthost = {
                  rule = "Host(`ssltest.crussell.io`)";
                  service = "test";
                  entryPoints = [ "websecure" ];
                  tls.certResolver = "letsencrypt";
                };
              };
              middlewares = {
                https-redirect = {
                  redirectScheme = {
                    scheme = "https";
                    permanent = true;
                  };
                };
              };
              services = {
                test.loadBalancer.servers = [{ url = "http://192.168.1.202:80"; }];
                mealie-svc.loadBalancer.servers = [{ url = "http://192.168.1.202:9925"; }];
                homeassistant-svc.loadBalancer.servers = [{ url = "http://192.168.1.51:8123"; }];
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
          
          VM_IP="REPLACE_ME"
          KEY_FILE="age-key.txt"
          
          if [ ! -f "$KEY_FILE" ]; then
            echo "Error: $KEY_FILE not found in current directory"
            exit 1
          fi
          
          echo "Deploying age key to VM at $VM_IP..."
          scp "$KEY_FILE" "root@$VM_IP:/tmp/"
          ssh "root@$VM_IP" "mv /tmp/$KEY_FILE /etc/sops/age/keys.txt && chmod 600 /etc/sops/age/keys.txt"
          echo "Age key deployed successfully!"
          
          echo "Testing secrets access..."
          ssh "root@$VM_IP" "tailscale-api-test"
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
          inherit system;
          modules = [
            ./hetzner-bootstrap/configuration.nix
            disko.nixosModules.disko
          ];
          specialArgs = {
            inherit disko;
          };
        };
      };
    };
}