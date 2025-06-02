{ pkgs, config, lib, ... }: {
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
}