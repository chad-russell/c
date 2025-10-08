{ config, ... }:

{
  # Memos - A privacy-first, lightweight note-taking service
  
  virtualisation.quadlet = let
    inherit (config.virtualisation.quadlet) networks volumes;
  in {
    # Network for Memos
    networks.memos = {
      networkConfig.name = "memos";
    };

    # Volume for data persistence
    volumes.memos-data = {
      volumeConfig.name = "memos-data";
    };

    # Memos container
    containers.memos = {
      containerConfig = {
        image = "docker.io/neosmemo/memos:stable";
        networks = [ networks.memos.ref ];
        publishPorts = [ "5230:5230" ];
        volumes = [ "${volumes.memos-data.ref}:/var/opt/memos" ];
        # Optional: Add environment variables for configuration
        # environments = {
        #   MEMOS_DRIVER = "postgres";
        #   MEMOS_DSN = "postgresql://user:password@host:port/dbname";
        #   MEMOS_MODE = "prod";
        #   MEMOS_ADDR = "0.0.0.0";
        #   MEMOS_PORT = "5230";
        # };
      };
      serviceConfig = {
        Restart = "always";
        TimeoutStartSec = "900";
      };
    };
  };
}
