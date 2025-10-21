{ config, ... }:

{
  # Karakeep - Bookmark Manager with AI-powered features
  # Requires: Meilisearch (search engine) and Chrome (for web scraping)
  
  virtualisation.quadlet = let
    inherit (config.virtualisation.quadlet) containers networks volumes;
  in {
    # Network for all Karakeep services
    networks.karakeep = {
      networkConfig.name = "karakeep";
    };

    # Volumes
    volumes.karakeep-app-data = {
      volumeConfig.name = "karakeep-app-data";
    };

    volumes.karakeep-data = {
      volumeConfig.name = "karakeep-data";
    };

    volumes.karakeep-homedash-config = {
      volumeConfig.name = "karakeep-homedash-config";
    };

    # Chrome container for web scraping
    containers.karakeep-chrome = {
      containerConfig = {
        image = "gcr.io/zenika-hub/alpine-chrome:124";
        networks = [ networks.karakeep.ref ];
        exec = [
          "--no-sandbox"
          "--disable-gpu"
          "--disable-dev-shm-usage"
          "--remote-debugging-address=0.0.0.0"
          "--remote-debugging-port=9222"
          "--hide-scrollbars"
        ];
      };
      serviceConfig = {
        Restart = "always";
        TimeoutStartSec = "900";
      };
    };

    # Meilisearch search engine
    containers.karakeep-meilisearch = {
      containerConfig = {
        image = "docker.io/getmeili/meilisearch:v1.10";
        networks = [ networks.karakeep.ref ];
        volumes = [ "${volumes.karakeep-data.ref}:/meili_data" ];
        environments = {
          # CHANGE THIS: Generate a secure master key with: openssl rand -base64 36
          MEILI_MASTER_KEY = "IrLHvlILqJDWOufv/wweLQondy1+rq3JufEOXoJg/2sMjkGS";
        };
      };
      serviceConfig = {
        Restart = "always";
        TimeoutStartSec = "900";
      };
    };

    # Main Karakeep application
    containers.karakeep = {
      containerConfig = {
        image = "ghcr.io/karakeep-app/karakeep:release";
        networks = [ networks.karakeep.ref ];
        publishPorts = [ "3322:3000" ];
        volumes = [ "${volumes.karakeep-app-data.ref}:/data" ];
        environments = {
          # CHANGE THIS: Generate a secure secret with: openssl rand -base64 36
          NEXTAUTH_SECRET = "FLGHUFil//n1atELBxGFD7FNF9D8Jpom9cFLHrB1JFFWmuyp";
          # CHANGE THIS: Set to your actual server URL
          NEXTAUTH_URL = "https://karakeep.internal.crussell.io";
          DATA_DIR = "/data";
          # Meilisearch configuration
          MEILI_ADDR = "http://karakeep-meilisearch:7700";
          MEILI_MASTER_KEY = "IrLHvlILqJDWOufv/wweLQondy1+rq3JufEOXoJg/2sMjkGS";
          # Chrome configuration
          BROWSER_WEB_URL = "http://karakeep-chrome:9222";
        };
      };
      unitConfig = {
        Requires = [ containers.karakeep-meilisearch.ref containers.karakeep-chrome.ref ];
        After = [ containers.karakeep-meilisearch.ref containers.karakeep-chrome.ref ];
      };
      serviceConfig = {
        Restart = "always";
        TimeoutStartSec = "900";
      };
    };

    # HomeDash - Compact bookmark dashboard
    containers.karakeep-homedash = {
      containerConfig = {
        image = "ghcr.io/codejawn/karakeep-homedash:latest";
        networks = [ networks.karakeep.ref ];
        publishPorts = [ "8595:8595" ];
        volumes = [
          "${volumes.karakeep-app-data.ref}:/mnt/karakeep-data:ro"
          "${volumes.karakeep-homedash-config.ref}:/app/config"
        ];
        exec = [
          "/bin/sh"
          "-c"
          "ln -sf /mnt/karakeep-data/db.db /app/db.db && python3 server.py"
        ];
        environments = {
          # CHANGE THIS: Set to your actual KaraKeep URL
          KARAKEEP_URL = "https://karakeep.internal.crussell.io";
        };
      };
      unitConfig = {
        Requires = [ containers.karakeep.ref ];
        After = [ containers.karakeep.ref ];
      };
      serviceConfig = {
        Restart = "always";
        TimeoutStartSec = "900";
      };
    };
  };
}
