{
  description = "Home Compute Cluster -- test node 1";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixos-generators.url = "github:nix-community/nixos-generators";
    sops-nix.url = "github:Mic92/sops-nix";
  };

  outputs = { self, nixpkgs, nixos-generators, sops-nix, ... }:
    let
      system = "x86_64-linux";

      nginxModule = { pkgs, ... }: {
        networking.hostName = "vm-test";
        networking.firewall.allowedTCPPorts = [ 22 80 ];
        networking.useDHCP = false;
        networking.defaultGateway = "192.168.68.1";
        networking.nameservers = [ "1.1.1.1" "8.8.8.8" ];

        networking.interfaces.ens18 = {
          ipv4.addresses = [{
            address = "192.168.68.211";
            prefixLength = 22;
          }];
        };

        services.openssh.enable = true;
        services.openssh.settings = {
          PermitRootLogin = "yes";
          PasswordAuthentication = true;
        };

        services.nginx = {
          enable = true;
          virtualHosts."default" = {
            root = "/var/www";
            listen = [
              { addr = "0.0.0.0"; port = 80; }
            ];
            default = true;
          };
        };

        systemd.tmpfiles.rules = [
          "d /var/www 0755 root root -"
          "f /var/www/index.html 0644 root root - <h1>Hello from NixOS + nginx!</h1>"
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
        networking.defaultGateway = "192.168.68.1";
        networking.nameservers = [ "1.1.1.1" "8.8.8.8" ];

        networking.interfaces.ens18 = {
          ipv4.addresses = [{
            address = "192.168.68.212";
            prefixLength = 22;
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
                { domain = "*.internal.crussell.io"; answer = "192.168.68.212"; }
                { domain = "homeassistant.crussell.io"; answer = "192.168.68.212"; }
                { domain = "ssltest.crussell.io"; answer = "192.168.68.212"; }
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
              caServer = "https://acme-staging-v02.api.letsencrypt.org/directory";
              dnsChallenge = {
                provider = "route53";
                delayBeforeCheck = 60;
                resolvers = [ "1.1.1.1:53" "8.8.8.8:53" ];
              };
            };
            log.level = "DEBUG";
            providers.file = {
              filename = config.sops.templates."traefik-dynamic.yaml".path;
              watch = true;
            };
          };

          # dynamicConfigFile = config.sops.templates."traefik-dynamic.yaml".path;

          # dynamicConfigOptions = { # THIS WILL BE REMOVED
          # };

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

        sops.templates."traefik-dynamic.yaml" = {
          content = ''
            certificatesResolvers:
              letsencrypt:
                acme:
                  email: ${config.sops.placeholder.letsencrypt-email}

            http:
              routers:
                test:
                  rule: "Host(`test.internal.crussell.io`)"
                  service: "test"
                  entryPoints:
                    - "web"
                homeassistant:
                  rule: "Host(`homeassistant.crussell.io`)"
                  service: "homeassistant-svc"
                  entryPoints:
                    - "websecure"
                  tls:
                    certResolver: "letsencrypt"
                homeassistant-http-redirect:
                  rule: "Host(`homeassistant.crussell.io`)"
                  entryPoints:
                    - "web"
                  middlewares:
                    - "https-redirect"
                  service: "noop@internal"
                ssltesthost:
                  rule: "Host(`ssltest.crussell.io`)"
                  service: "test"
                  entryPoints:
                    - "websecure"
                  tls:
                    certResolver: "letsencrypt"

              middlewares:
                https-redirect:
                  redirectScheme:
                    scheme: "https"
                    permanent: true
                homeassistant-headers:
                  headers:
                    customRequestHeaders:
                      "X-Forwarded-Proto": "https"

              services:
                test:
                  loadBalancer:
                    servers:
                      - url: "http://192.168.68.211:80"
                homeassistant-svc:
                  loadBalancer:
                    servers:
                      - url: "http://192.168.68.51:8123"
          '';
          owner = "root";
          group = "traefik";
          mode = "0440";
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
          modules = [ nginxModule ];
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
          
          VM_IP="192.168.68.212"
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
      };

      nixosConfigurations.gateway = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [ (makeGatewayModule { includeBootConfig = true; }) ];
      };

      nixosConfigurations.nginx = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [ nginxModule ];
      };
    };
}