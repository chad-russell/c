{ sops-nix, config, pkgs, ... }: {
  imports = [ sops-nix.nixosModules.sops ];

  virtualisation = {
    podman = {
      enable = true;
      dockerCompat = true; # For docker-compose compatibility
    };
    oci-containers = {
      backend = "podman";
      containers = {
        beszel-agent = {
          image = "henrygd/beszel-agent:latest";
          autoStart = true;
          user = "1000"; # Assuming crussell user (UID 1000)
          volumes = [
            "/var/lib/beszel_socket:/beszel_socket"
          ];
          environment = {
            LISTEN = "0.0.0.0:45876";
          };
          environmentFiles = [ config.sops.templates."beszel-agent-env".path ];
          extraOptions = [
            "--network=host"
          ];
        };
      };
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/beszel_socket 0755 crussell users -" # Ensure crussell (UID 1000) has access
    "Z /var/lib/beszel_socket 0755 crussell users -"
  ];

  # Open firewall port for the agent
  networking.firewall.allowedTCPPorts = [ 45876 ];

  # SOPS secret for beszel-agent key
  sops.secrets.beszel-agent-key = {
    owner = "root"; # Or specific user if needed, but agent runs as UID 1000
    group = "root"; # Or specific group
    mode = "0400";
  };

  # SOPS template for beszel-agent env file
  sops.templates."beszel-agent-env" = {
    content = ''
      KEY=${config.sops.placeholder.beszel-agent-key}
    '';
    owner = "root";
    group = "root";
    mode = "0444";
  };

  # Ensure the 'users' group exists if not defined elsewhere globally
  users.groups.users = {}; # Or ensure crussell is part of a group that has write access to /var/lib/beszel_socket

  # Ensure podman is available
  environment.systemPackages = [ pkgs.podman ];
} 