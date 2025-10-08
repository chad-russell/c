{ config, ... }:

{
  # Papra - Document Management System
  
  virtualisation.quadlet = let
    inherit (config.virtualisation.quadlet) networks volumes;
  in {
    # Network for Papra
    networks.papra = {
      networkConfig.name = "papra";
    };

    # Volume for data persistence (database and documents)
    volumes.papra-data = {
      volumeConfig.name = "papra-data";
    };

    # Papra container
    containers.papra = {
      containerConfig = {
        image = "ghcr.io/papra-hq/papra:latest";
        networks = [ networks.papra.ref ];
        publishPorts = [ "1221:1221" ];
        volumes = [ "${volumes.papra-data.ref}:/app/app-data" ];
        environments = {
          # CHANGE THIS: Set to your actual Papra URL
          APP_BASE_URL = "https://papra.internal.crussell.io";
          TZ = "America/New_York";
          # Optional configuration:
          # PAPRA_LOG_LEVEL = "info";
          # PAPRA_MAX_UPLOAD_SIZE = "50MB";
        };
      };
      serviceConfig = {
        Restart = "always";
        TimeoutStartSec = "900";
      };
    };
  };
}
