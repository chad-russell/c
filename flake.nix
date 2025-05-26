{
  description = "Home Compute Cluster -- test node 1";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixos-generators.url = "github:nix-community/nixos-generators";
  };

  outputs = { self, nixpkgs, nixos-generators, ... }:
    let
      system = "x86_64-linux";
    in {
      packages.${system}.proxmoxImage = nixos-generators.nixosGenerate {
        inherit system;
        format = "proxmox";
        modules = [
          ({ pkgs, ... }: {
            networking.hostName = "vm-p2-103";
            networking.firewall.allowedTCPPorts = [ 22 80 ];
            networking.useDHCP = false;
            networking.defaultGateway = "192.168.68.1";
            networking.nameservers = [ "1.1.1.1" "8.8.8.8" ];

            networking.interfaces.ens18 = {
              ipv4.addresses = [{
                address = "192.168.68.211";
                prefixLength = 22;
              }];
            };

            services.openssh.enable = true;

            services.nginx = {
              enable = true;
              virtualHosts."default" = {
                root = "/var/www";
                listen = [
                  { addr = "0.0.0.0"; port = 80; }
                ];
                default = true;
              };
            };

            systemd.tmpfiles.rules = [
              "d /var/www 0755 root root -"
              "f /var/www/index.html 0644 root root - <h1>Hello from NixOS + nginx!</h1>"
            ];

            users.users.root = {
              password = "password";
            };

            system.stateVersion = "25.05";
          })
        ];
      };
    };
}