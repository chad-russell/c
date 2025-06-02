{ pkgs, config, lib, ... }: {
    imports = [ ../hetzner-bootstrap/configuration.nix ];
    
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

    systemd.tmpfiles.rules = [
        "d /var/lib/traefik 0755 traefik traefik -"
    ];
}