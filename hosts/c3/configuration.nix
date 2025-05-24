{ config, pkgs, lib, ... }:

{
  imports = [ ];

  # SeaweedFS configuration for c3
  # c3 will run: Master and Volume (no filer)
  services.seaweedfs = {
    master = {
      enable = true;
      ip = "192.168.68.73";
      port = 9333;
      peers = [
        "192.168.68.71:9333"  # c1
        "192.168.68.72:9333"  # c2  
        "192.168.68.73:9333"  # c3
      ];
    };
    
    volume = {
      enable = true;
      ip = "192.168.68.73";
      port = 8080;
      mserver = "192.168.68.71:9333,192.168.68.72:9333,192.168.68.73:9333";
      dir = "/var/lib/seaweedfs/volume";
    };
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

  # Create SeaweedFS directories
  system.activationScripts.seaweedfs-setup = ''
    mkdir -p /var/lib/seaweedfs/volume
    mkdir -p /var/lib/seaweedfs/master
    chown -R seaweedfs:seaweedfs /var/lib/seaweedfs
  '';

  # Open firewall ports for SeaweedFS and Keepalived
  networking.firewall.allowedTCPPorts = [ 
    9333  # Master
    8080  # Volume 
  ];
  
  # VRRP protocol for Keepalived
  networking.firewall.allowedUDPPorts = [ 112 ];
  networking.firewall.extraCommands = ''
    iptables -A INPUT -p vrrp -j ACCEPT
    iptables -A OUTPUT -p vrrp -j ACCEPT
  '';
} 