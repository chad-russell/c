{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.containerBackup;

  # Define the options for the backup service
  jobOptions = { name, ... }: {
    options = {
      containerName = mkOption {
        type = types.str;
        description = "Name of the docker container to stop/start.";
      };
      volumes = mkOption {
        type = types.listOf types.str;
        description = "List of docker volumes to backup.";
      };
      keepDays = mkOption {
        type = types.int;
        default = 7;
        description = "Number of days to keep backups.";
      };
    };
  };

in {
  options.services.containerBackup = {
    enable = mkEnableOption "Automated container backups to NFS";

    nfsServer = mkOption {
      type = types.str;
      default = "192.168.20.31";
      description = "NFS server IP address.";
    };

    nfsPath = mkOption {
      type = types.str;
      default = "/mnt/tank/backups";
      description = "NFS share path.";
    };

    mountPoint = mkOption {
      type = types.str;
      default = "/mnt/backups";
      description = "Local mount point for the NFS share.";
    };

    jobs = mkOption {
      type = types.attrsOf (types.submodule jobOptions);
      default = {};
      description = "Backup jobs configuration.";
    };
  };

  config = mkIf cfg.enable {
    # 1. Mount the NFS share
    fileSystems."${cfg.mountPoint}" = {
      device = "${cfg.nfsServer}:${cfg.nfsPath}";
      fsType = "nfs";
      options = [ 
        "x-systemd.automount" 
        "noauto" 
        "timeo=14" 
        "nfsvers=4"
        "rw"
        "soft"
        "intr"
      ];
    };

    # 2. Create the backup script and systemd service for each job
    systemd.services = mapAttrs' (name: job: nameValuePair "container-backup-${name}" {
      description = "Backup service for container ${job.containerName}";
      requires = [ "docker.service" ];
      after = [ "docker.service" "network.target" "remote-fs.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
      path = with pkgs; [ docker gzip gnutar coreutils findutils ];
      script = ''
        set -euo pipefail
        
        BACKUP_DIR="${cfg.mountPoint}/containers/${name}"
        TIMESTAMP=$(date +%Y%m%d-%H%M%S)
        mkdir -p "$BACKUP_DIR"

        echo "Starting backup for ${name}..."

        # Stop the container
        echo "Stopping container ${job.containerName}..."
        docker stop "${job.containerName}"

        # Backup volumes
        for vol in ${toString job.volumes}; do
          echo "Backing up volume $vol..."
          # Use a temporary alpine container to tar the volume
          # We mount the volume to /data and the backup dir to /backup
          docker run --rm \
            -v "$vol":/data:ro \
            -v "$BACKUP_DIR":/backup \
            alpine:latest \
            tar czf "/backup/$TIMESTAMP-$vol.tar.gz" -C /data .
        done

        # Start the container
        echo "Starting container ${job.containerName}..."
        docker start "${job.containerName}"

        # Prune old backups
        echo "Pruning backups older than ${toString job.keepDays} days..."
        find "$BACKUP_DIR" -name "*.tar.gz" -mtime +${toString job.keepDays} -delete
        
        echo "Backup for ${name} completed successfully."
      '';
    }) cfg.jobs;

    # 3. Create a timer to trigger the backups
    # For simplicity, we'll create one timer that triggers all backup services, 
    # OR we can just rely on the services being triggered individually if we want different schedules.
    # The plan said "daily (e.g., at 3 AM)". Let's make a target that runs them all.
    
    systemd.targets.container-backup = {
      description = "Target to run all container backups";
      wants = map (name: "container-backup-${name}.service") (attrNames cfg.jobs);
    };

    systemd.timers.container-backup = {
      description = "Daily container backup timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "03:00:00";
        Persistent = true;
        Unit = "container-backup.target";
      };
    };
  };
}
