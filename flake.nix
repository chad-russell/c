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
      packages.${system} = {
        nginx = nixos-generators.nixosGenerate {
          inherit system;
          format = "proxmox";
          modules = [
            ({ pkgs, ... }: {
              networking.hostName = "vm-test";
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

        traefik = nixos-generators.nixosGenerate {
          inherit system;
          format = "proxmox";
          modules = [
            ({ pkgs, ... }: {
              networking.hostName = "vm-reverse-proxy";
              networking.firewall.allowedTCPPorts = [ 80 443 22 3000 8080 ];
              networking.firewall.allowedUDPPorts = [ 53 ];
              networking.useDHCP = false;
              networking.defaultGateway = "192.168.68.1";
              networking.nameservers = [ "1.1.1.1" "8.8.8.8" ];

              networking.interfaces.ens18 = {
                ipv4.addresses = [{
                  address = "192.168.68.212";
                  prefixLength = 22;
                }];
              };

              services.openssh.enable = true;

              services.resolved.enable = false;

              services.adguardhome = {
                enable = true;
                settings = {
                  http.address = "0.0.0.0:3000";
                  dns = {
                    bind_hosts = [ "0.0.0.0" ];
                    port = 53;
                    upstream_dns = [
                      "1.1.1.1"
                      "8.8.8.8"
                    ];
                    rewrites = [
                      { domain = "test.internal.crussell.io"; answer = "192.168.68.212"; }
                    ];
                  };
                  filtering.enabled = true;
                };
              };

              services.traefik = {
                enable = true;
                staticConfigOptions = {
                  entryPoints = {
                    web.address = ":80";
                    websecure.address = ":443";
                  };
                  api = {
                    dashboard = true;
                    insecure = true;
                  };
                };

                dynamicConfigOptions = {
                  http = {
                    routers = {
                      test = {
                        rule = "Host(`test.internal.crussell.io`)";
                        service = "test";
                        entryPoints = [ "web" ];
                      };
                    };
                    services = {
                      test.loadBalancer.servers = [
                        { url = "http://192.168.68.211:80"; }
                      ];
                    };
                  };
                };
              };

              systemd.tmpfiles.rules = [
                "d /var/lib/traefik 0755 traefik traefik -"
              ];

              users.users.root = {
                password = "password";
              };

              system.stateVersion = "25.05";
            })
          ];
        };
      };
    };
}