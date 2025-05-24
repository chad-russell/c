{ config, pkgs, lib, ... }:

{
  imports = [ 
    ../../modules/seaweedfs.nix
  ];

  # SeaweedFS cluster configuration for c1
  # c1 will run: Master, Volume, and Filer
  services.seaweedfs-cluster = {
    enable = true;
    nodeIp = "192.168.68.71";
    masterPeers = [
      "192.168.68.71:9333"  # c1
      "192.168.68.72:9333"  # c2  
      "192.168.68.73:9333"  # c3
    ];
    enableMaster = true;
    enableVolume = true;
    enableFiler = true;
  };

  # Keepalived configuration for HA
  services.keepalived = {
    enable = true;
    vrrpInstances.VI_1 = {
      state = "MASTER";  # c1 is the primary master
      interface = "eno1";
      virtualRouterId = 1;
      priority = 120;  # Highest priority for c1
      virtualIps = [{
        addr = "192.168.68.70";
        prefixLen = 24;
      }];
    };
  };

  # Create SeaweedFS directories
  system.activationScripts.seaweedfs-setup = ''
    mkdir -p /var/lib/seaweedfs/volume
    mkdir -p /var/lib/seaweedfs/filer
    mkdir -p /var/lib/seaweedfs/master
    chown -R seaweedfs:seaweedfs /var/lib/seaweedfs
  '';

  # Open firewall ports for SeaweedFS and Keepalived
  networking.firewall.allowedTCPPorts = [ 
    9333  # Master
    8080  # Volume 
    8888  # Filer
  ];
  
  # VRRP protocol for Keepalived
  networking.firewall.allowedUDPPorts = [ 112 ];
  networking.firewall.extraCommands = ''
    iptables -A INPUT -p vrrp -j ACCEPT
    iptables -A OUTPUT -p vrrp -j ACCEPT
  '';
} 