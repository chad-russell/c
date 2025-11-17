{ config, pkgs, ... }:

{
  # Beszel - Lightweight server monitoring platform
  # Using native NixOS service for the hub
  
  services.beszel.hub = {
    enable = true;
    
    # Host and port configuration
    host = "0.0.0.0";  # Listen on all interfaces
    port = 8090;       # Default beszel port
    
    # Data directory for beszel hub
    dataDir = "/var/lib/beszel-hub";
    
    # Environment variables for additional configuration
    environment = {
      # Timezone setting
      TZ = "America/New_York";
    };
    
    # You can also use environmentFile for secrets
    # environmentFile = "/etc/beszel/secrets.env";
  };
  
  # Open firewall port for beszel hub
  networking.firewall.allowedTCPPorts = [ 8090 ];
}

