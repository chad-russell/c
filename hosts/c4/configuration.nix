{ config, pkgs, lib, ... }:

{
  imports = [ 
    ../../modules/seaweedfs.nix
  ];

  # SeaweedFS cluster configuration for c4
  # c4 will run: Volume only (no master or filer)
  services.seaweedfs-cluster = {
    enable = true;
    nodeIp = "192.168.68.74";
    masterPeers = [
      "192.168.68.71:9333"  # c1
      "192.168.68.72:9333"  # c2  
      "192.168.68.73:9333"  # c3
    ];
    enableMaster = false;
    enableVolume = true;
    enableFiler = false;
  };

  # Keepalived configuration for HA
  services.keepalived = {
    enable = true;
    vrrpInstances.VI_1 = {
      state = "BACKUP";
      interface = "eno1";
      virtualRouterId = 1;
      priority = 90;  # Lowest priority for c4
      virtualIps = [
        { addr = "192.168.68.70/24"; }
      ];
    };
  };

  # Create SeaweedFS directories
  system.activationScripts.seaweedfs-setup = ''
    mkdir -p /var/lib/seaweedfs/volume
    chown -R seaweedfs:seaweedfs /var/lib/seaweedfs
  '';

  # Open firewall ports for SeaweedFS and Keepalived
  networking.firewall.allowedTCPPorts = [ 
    8080  # Volume 
  ];
  
  # VRRP protocol for Keepalived
  networking.firewall.allowedUDPPorts = [ 112 ];
  networking.firewall.extraCommands = ''
    iptables -A INPUT -p vrrp -j ACCEPT
    iptables -A OUTPUT -p vrrp -j ACCEPT
  '';
} 