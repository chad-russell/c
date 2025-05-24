{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.seaweedfs-cluster;
in

{
  options.services.seaweedfs-cluster = {
    enable = mkEnableOption "SeaweedFS cluster node";

    nodeIp = mkOption {
      type = types.str;
      description = "IP address of this node";
    };

    masterPeers = mkOption {
      type = types.listOf types.str;
      description = "List of master peer addresses";
      example = [ "192.168.68.71:9333" "192.168.68.72:9333" "192.168.68.73:9333" ];
    };

    enableMaster = mkOption {
      type = types.bool;
      default = true;
      description = "Enable master server on this node";
    };

    enableVolume = mkOption {
      type = types.bool;  
      default = true;
      description = "Enable volume server on this node";
    };

    enableFiler = mkOption {
      type = types.bool;
      default = false;
      description = "Enable filer server on this node";
    };

    masterPort = mkOption {
      type = types.port;
      default = 9333;
      description = "Master server port";
    };

    volumePort = mkOption {
      type = types.port;
      default = 8080;
      description = "Volume server port";
    };

    filerPort = mkOption {
      type = types.port;
      default = 8888;
      description = "Filer server port";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/seaweedfs";
      description = "Data directory for SeaweedFS";
    };
  };

  config = mkIf cfg.enable {
    # Install SeaweedFS package
    environment.systemPackages = [ pkgs.seaweedfs ];

    # Create SeaweedFS user and group
    users.users.seaweedfs = {
      isSystemUser = true;
      group = "seaweedfs";
      home = cfg.dataDir;
      createHome = true;
    };
    users.groups.seaweedfs = {};

    # SeaweedFS Master service
    systemd.services.seaweedfs-master = mkIf cfg.enableMaster {
      description = "SeaweedFS Master Server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "simple";
        User = "seaweedfs";
        Group = "seaweedfs";
        ExecStart = "${pkgs.seaweedfs}/bin/weed master -ip=${cfg.nodeIp} -port=${toString cfg.masterPort} -peers=${concatStringsSep "," cfg.masterPeers} -mdir=${cfg.dataDir}/master";
        Restart = "always";
        RestartSec = "10s";
        
        # Security settings
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ cfg.dataDir ];
      };
      
      preStart = ''
        mkdir -p ${cfg.dataDir}/master
        chown -R seaweedfs:seaweedfs ${cfg.dataDir}/master
      '';
    };

    # SeaweedFS Volume service  
    systemd.services.seaweedfs-volume = mkIf cfg.enableVolume {
      description = "SeaweedFS Volume Server";
      after = [ "network.target" ] ++ optional cfg.enableMaster "seaweedfs-master.service";
      wants = optional cfg.enableMaster "seaweedfs-master.service";
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "simple";
        User = "seaweedfs";
        Group = "seaweedfs";
        ExecStart = "${pkgs.seaweedfs}/bin/weed volume -ip=${cfg.nodeIp} -port=${toString cfg.volumePort} -mserver=${concatStringsSep "," cfg.masterPeers} -dir=${cfg.dataDir}/volume";
        Restart = "always";
        RestartSec = "10s";
        
        # Security settings
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ cfg.dataDir ];
      };
      
      preStart = ''
        mkdir -p ${cfg.dataDir}/volume
        chown -R seaweedfs:seaweedfs ${cfg.dataDir}/volume
      '';
    };

    # SeaweedFS Filer service
    systemd.services.seaweedfs-filer = mkIf cfg.enableFiler {
      description = "SeaweedFS Filer Server";
      after = [ "network.target" "seaweedfs-master.service" ];
      wants = [ "seaweedfs-master.service" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "simple";
        User = "seaweedfs";
        Group = "seaweedfs";
        ExecStart = "${pkgs.seaweedfs}/bin/weed filer -ip=${cfg.nodeIp} -port=${toString cfg.filerPort} -master=${concatStringsSep "," cfg.masterPeers}";
        Restart = "always";
        RestartSec = "10s";
        
        # Security settings
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ cfg.dataDir ];
      };
    };

    # Open firewall ports
    networking.firewall.allowedTCPPorts = 
      (optional cfg.enableMaster cfg.masterPort) ++
      (optional cfg.enableVolume cfg.volumePort) ++
      (optional cfg.enableFiler cfg.filerPort);
  };
} 