{ config, pkgs, lib, ... }:

{
  # Import common configuration
  imports = [
    ../../modules/common.nix
  ];

  # Host-specific configuration
  networking.hostName = "c3";
  
  # Containerized applications for c3
  virtualisation.oci-containers = {
    backend = "podman";
    containers = {
      nginx-web = {
        image = "nginx:alpine";
        ports = [ "8080:80" ];
        volumes = [
          "/var/lib/nginx-data:/usr/share/nginx/html:ro"
        ];
        environment = {
          NGINX_HOST = "c3.local";
          NGINX_PORT = "80";
        };
        extraOptions = [
          "--restart=unless-stopped"
          "--pull=newer"
        ];
      };
    };
  };

  # Create directory for nginx content
  systemd.tmpfiles.rules = [
    "d /var/lib/nginx-data 0755 root root -"
  ];

  # Create a simple index.html
  environment.etc."nginx-content/index.html" = {
    text = ''
      <!DOCTYPE html>
      <html>
      <head>
          <title>C3 Node - Container Demo</title>
          <style>
              body { font-family: Arial, sans-serif; margin: 40px; background: #f4f4f4; }
              .container { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
              h1 { color: #333; }
              .info { background: #e7f3ff; padding: 15px; border-left: 4px solid #2196F3; margin: 20px 0; }
          </style>
      </head>
      <body>
          <div class="container">
              <h1>🐳 C3 Node - Containerized Application</h1>
              <div class="info">
                  <strong>Host:</strong> c3 (192.168.68.73)<br>
                  <strong>Container:</strong> nginx:alpine<br>
                  <strong>Runtime:</strong> Podman<br>
                  <strong>Port:</strong> 8080
              </div>
              <p>This is a demonstration of a containerized application running on the C3 node using Podman.</p>
              <p>The container is managed by NixOS and will automatically restart on system boot.</p>
          </div>
      </body>
      </html>
    '';
    target = "nginx-content/index.html";
  };

  # Copy the content to the nginx data directory
  system.activationScripts.nginx-content = ''
    cp /etc/nginx-content/index.html /var/lib/nginx-data/
    chown root:root /var/lib/nginx-data/index.html
    chmod 644 /var/lib/nginx-data/index.html
  '';

  # Open firewall for the web service
  networking.firewall.allowedTCPPorts = [ 8080 ];

  # Additional packages for container management
  environment.systemPackages = with pkgs; [
    podman-compose
    podman-tui
  ];
} 