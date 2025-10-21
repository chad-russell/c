{ config, ... }:

{
  # ntfy - Simple HTTP-based pub-sub notification service
  
  virtualisation.quadlet = let
    inherit (config.virtualisation.quadlet) networks volumes;
  in {
    # Network for ntfy
    networks.ntfy = {
      networkConfig.name = "ntfy";
    };

    # Volume for cache and attachments
    volumes.ntfy-cache = {
      volumeConfig.name = "ntfy-cache";
    };

    # Volume for configuration
    volumes.ntfy-config = {
      volumeConfig.name = "ntfy-config";
    };

    # ntfy container
    containers.ntfy = {
      containerConfig = {
        image = "docker.io/binwiederhier/ntfy:v2.11.0";
        networks = [ networks.ntfy.ref ];
        publishPorts = [ "8090:80" ];
        volumes = [
          "${volumes.ntfy-cache.ref}:/var/cache/ntfy"
          "${volumes.ntfy-config.ref}:/etc/ntfy"
        ];
        environments = {
          TZ = "America/New_York";
        };
        # Command to run ntfy server
        exec = "serve";
      };
      serviceConfig = {
        Restart = "unless-stopped";
        TimeoutStartSec = "900";
      };
    };
  };
}
