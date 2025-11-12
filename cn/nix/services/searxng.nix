{ config, ... }:

{
  # SearXNG - Privacy-respecting metasearch engine
  # Requires: Valkey for caching
  
  virtualisation.quadlet = let
    inherit (config.virtualisation.quadlet) containers networks volumes;
  in {
    # Network for SearXNG services
    networks.searxng = {
      networkConfig.name = "searxng";
    };

    # Volumes
    volumes.searxng-config = {
      volumeConfig.name = "searxng-config";
    };

    volumes.searxng-cache = {
      volumeConfig.name = "searxng-cache";
    };

    volumes.searxng-valkey-data = {
      volumeConfig.name = "searxng-valkey-data";
    };

    # Valkey cache for SearXNG
    containers.searxng-valkey = {
      containerConfig = {
        image = "docker.io/valkey/valkey:8-alpine";
        networks = [ networks.searxng.ref ];
        volumes = [ "${volumes.searxng-valkey-data.ref}:/data" ];
        exec = [
          "valkey-server"
          "--save"
          "30"
          "1"
          "--loglevel"
          "warning"
        ];
      };
      serviceConfig = {
        Restart = "always";
        TimeoutStartSec = "900";
      };
    };

    # SearXNG container
    containers.searxng = {
      containerConfig = {
        image = "docker.io/searxng/searxng:latest";
        networks = [ networks.searxng.ref ];
        publishPorts = [ "8080:8080" ];
        volumes = [
          "${volumes.searxng-config.ref}:/etc/searxng"
          "${volumes.searxng-cache.ref}:/var/cache/searxng"
        ];
        environments = {
          # Base URL for SearXNG
          SEARXNG_BASE_URL = "https://searxng.internal.crussell.io/";
        };
      };
      unitConfig = {
        Requires = [ containers.searxng-valkey.ref ];
        After = [ containers.searxng-valkey.ref ];
      };
      serviceConfig = {
        Restart = "always";
        TimeoutStartSec = "900";
      };
    };
  };
}

