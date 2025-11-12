{ config, ... }:

{
  # PinePods - Podcast Management System
  # Requires: PostgreSQL database and Valkey cache
  
  virtualisation.quadlet = let
    inherit (config.virtualisation.quadlet) containers networks volumes;
  in {
    # Network for all PinePods services
    networks.pinepods = {
      networkConfig.name = "pinepods";
    };

    # Volumes
    volumes.pinepods-downloads = {
      volumeConfig.name = "pinepods-downloads";
    };

    volumes.pinepods-backups = {
      volumeConfig.name = "pinepods-backups";
    };

    volumes.pinepods-pgdata = {
      volumeConfig.name = "pinepods-pgdata";
    };

    # PostgreSQL database
    containers.pinepods-db = {
      autoStart = true;
      containerConfig = {
        image = "docker.io/library/postgres:17";
        networks = [ networks.pinepods.ref ];
        volumes = [ "${volumes.pinepods-pgdata.ref}:/var/lib/postgresql/data" ];
        environments = {
          POSTGRES_DB = "pinepods_database";
          POSTGRES_USER = "postgres";
          POSTGRES_PASSWORD = "myS3curepass";
          PGDATA = "/var/lib/postgresql/data/pgdata";
        };
      };
      serviceConfig = {
        Restart = "always";
        TimeoutStartSec = "900";
      };
    };

    # Valkey cache
    containers.pinepods-valkey = {
      autoStart = true;
      containerConfig = {
        image = "docker.io/valkey/valkey:8-alpine";
        networks = [ networks.pinepods.ref ];
      };
      serviceConfig = {
        Restart = "always";
        TimeoutStartSec = "900";
      };
    };

    # Main PinePods application
    containers.pinepods = {
      containerConfig = {
        image = "docker.io/madeofpendletonwool/pinepods:latest";
        networks = [ networks.pinepods.ref ];
        publishPorts = [ "8040:8040" ];
        volumes = [
          "${volumes.pinepods-downloads.ref}:/opt/pinepods/downloads"
          "${volumes.pinepods-backups.ref}:/opt/pinepods/backups"
        ];
        environments = {
          # Basic Server Info
          SEARCH_API_URL = "https://search.pinepods.online/api/search";
          PEOPLE_API_URL = "https://people.pinepods.online";
          HOSTNAME = "https://pinepods.internal.crussell.io";
          
          # Database Configuration
          DB_TYPE = "postgresql";
          DB_HOST = "pinepods-db";
          DB_PORT = "5432";
          DB_USER = "postgres";
          DB_PASSWORD = "myS3curepass";
          DB_NAME = "pinepods_database";
          
          # Valkey Settings
          VALKEY_HOST = "pinepods-valkey";
          VALKEY_PORT = "6379";
          
          # Debug and User Settings
          DEBUG_MODE = "false";
          PUID = "911";
          PGID = "911";
          TZ = "America/New_York";
        };
      };
      unitConfig = let
        dependencyServices = [
          "pinepods-db.service"
          "pinepods-valkey.service"
        ];
      in {
        Requires = dependencyServices;
        After = dependencyServices;
      };
      serviceConfig = {
        Restart = "always";
        TimeoutStartSec = "900";
      };
    };
  };
}

