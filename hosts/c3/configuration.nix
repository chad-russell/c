{ config, pkgs, lib, ... }:

{
  imports = [ 
    ../../modules/seaweedfs.nix
  ];

  # SeaweedFS cluster configuration for c3
  services.seaweedfs-cluster = {
    enable = true;
    nodeIp = "192.168.68.73";
    masterPeers = [
      "192.168.68.71:9333"  # c1
      "192.168.68.72:9333"  # c2  
      "192.168.68.73:9333"  # c3
    ];
    enableMaster = true;
    enableVolume = true;
    enableFiler = false;  # Can enable later if needed
  };

  # Keepalived configuration for HA
  services.keepalived = {
    enable = true;
    vrrpInstances.VI_1 = {
      state = "BACKUP";
      interface = "eno1";
      virtualRouterId = 1;
      priority = 100;  # Third priority for c3
      virtualIps = [{
        addr = "192.168.68.70";
        prefixLen = 24;
      }];
    };
  };

  # VRRP protocol for Keepalived
  networking.firewall.allowedUDPPorts = [ 112 ];
  networking.firewall.extraCommands = ''
    iptables -A INPUT -p vrrp -j ACCEPT
    iptables -A OUTPUT -p vrrp -j ACCEPT
  '';
} 