{ config, ... }:

{
  # n8n - Workflow Automation Platform
  
  virtualisation.quadlet = let
    inherit (config.virtualisation.quadlet) networks volumes;
  in {
    # Network for n8n
    networks.n8n = {
      networkConfig.name = "n8n";
    };

    # Volumes for data persistence
    volumes.n8n-data = {
      volumeConfig.name = "n8n-data";
    };

    volumes.n8n-files = {
      volumeConfig.name = "n8n-files";
    };

    # n8n container
    containers.n8n = {
      containerConfig = {
        image = "docker.n8n.io/n8nio/n8n:latest";
        networks = [ networks.n8n.ref ];
        publishPorts = [ "5678:5678" ];
        volumes = [
          "${volumes.n8n-data.ref}:/home/node/.n8n"
          "${volumes.n8n-files.ref}:/files"
        ];
        environments = {
          # Basic Configuration
          N8N_HOST = "n8n.crussell.io";
          N8N_PORT = "5678";
          N8N_PROTOCOL = "https";
          WEBHOOK_URL = "https://n8n.crussell.io/";
          
          # Timezone Configuration
          GENERIC_TIMEZONE = "America/New_York";
          TZ = "America/New_York";
          
          # Production Settings
          NODE_ENV = "production";
          N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS = "true";
          
          # Enable runners for better performance
          N8N_RUNNERS_ENABLED = "true";
        };
      };
      serviceConfig = {
        Restart = "always";
        TimeoutStartSec = "900";
      };
    };
  };
}

