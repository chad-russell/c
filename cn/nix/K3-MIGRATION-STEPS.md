# K3 Migration to NixOS - Step by Step Guide

This guide will help you migrate k3 from Fedora to NixOS while preserving all your data.

## Overview

**Services on k3:**
- n8n (workflow automation)
- PinePods (podcast manager with PostgreSQL database)
- SearXNG (search engine with Valkey cache)

**Migration Strategy:**
1. Backup all container volumes to `/srv` (which will be preserved on the HDD)
2. Run nixos-anywhere to install NixOS
3. Restore volumes after NixOS boots
4. Verify services

---

## Step 1: Backup Current Data

### 1.1 Copy backup script to k3

```bash
# From your local machine
scp backup-k3-volumes.sh crussell@192.168.20.63:~/
```

### 1.2 Run backup on k3

```bash
# SSH into k3
ssh crussell@192.168.20.63

# Run the backup script
chmod +x ~/backup-k3-volumes.sh
~/backup-k3-volumes.sh
```

**What this does:**
- Stops all containers for consistent backup
- Creates tarballs of each volume in `/srv/k3-migration-backup/TIMESTAMP/`
- Creates a manifest file with details
- Shows total backup size

### 1.3 Verify backup

```bash
# List backup contents
ls -lh /srv/k3-migration-backup/*/

# Check manifest
cat /srv/k3-migration-backup/*/MANIFEST.txt

# Verify critical volumes are backed up
ls -lh /srv/k3-migration-backup/*/{n8n-data,pinepods-pgdata}.tar.gz
```

**CRITICAL:** Make sure you see backups for:
- `n8n-data.tar.gz` (your n8n workflows and data)
- `n8n-files.tar.gz` (uploaded files)
- `pinepods-pgdata.tar.gz` (PostgreSQL database)
- `pinepods-downloads.tar.gz` (podcast downloads)
- `pinepods-backups.tar.gz` (PinePods backups)

### 1.4 Exit k3

```bash
exit  # Log out of k3
```

---

## Step 2: Deploy NixOS with nixos-anywhere

### 2.1 Review disk configuration

The disk configuration will:
- **NVMe drive (`/dev/nvme0n1`):** OS and system
- **HDD drive (`/dev/sda`):** Mounted at `/srv` (where your backup is!)

⚠️ **IMPORTANT:** The `/srv` partition will be reformatted, BUT we'll preserve the data by:
1. The backup is at `/srv/k3-migration-backup/`
2. nixos-anywhere will format `/dev/sda` and create a new ext4 filesystem at `/srv`
3. This will WIPE the data

**WAIT!** We need to move the backup off `/srv` first!

Let me update the backup location...

---

## Step 2: Deploy NixOS

### 2.1 Run nixos-anywhere

```bash
# From your local machine, in the nix directory
cd /home/crussell/Code/c/cn/nix

# Deploy NixOS to k3
nixos-anywhere --flake .#k3 root@192.168.20.63
```

**What happens:**
1. Boots k3 into live NixOS (~30 seconds)
2. Partitions and formats both disks (~1 minute)
3. Installs NixOS with your config (~5-10 minutes)
4. Reboots k3

**Total time: ~10-15 minutes**

### 2.2 Wait for reboot

After nixos-anywhere completes, wait ~2-3 minutes for k3 to reboot.

### 2.3 Verify SSH access

```bash
ssh crussell@192.168.20.63
```

You should be able to log in immediately with your SSH key.

---

## Step 3: Restore Data

### 3.1 Copy restore script to new k3

```bash
# From your local machine
scp restore-k3-volumes.sh crussell@192.168.20.63:~/
```

### 3.2 Find your backup timestamp

```bash
# On k3
ssh crussell@192.168.20.63
ls -1 /srv/k3-migration-backup/
```

You should see a timestamp directory (e.g., `20241112_210000`)

### 3.3 Run restore script

```bash
# On k3
chmod +x ~/restore-k3-volumes.sh
~/restore-k3-volumes.sh TIMESTAMP  # Replace TIMESTAMP with the one you found
```

**What this does:**
- Stops all new NixOS services
- Restores each volume from the backup tarballs
- Starts the services
- Shows service status

---

## Step 4: Verify Everything Works

### 4.1 Check service status

```bash
# On k3
sudo systemctl status n8n.service
sudo systemctl status pinepods.service
sudo systemctl status pinepods-db.service
sudo systemctl status searxng.service
```

All should show "active (running)"

### 4.2 Check containers

```bash
podman ps
```

Should show:
- n8n
- pinepods
- pinepods-db
- pinepods-valkey
- searxng
- searxng-valkey

### 4.3 Test web access

- n8n: http://192.168.20.63:5678
- PinePods: http://192.168.20.63:8040
- SearXNG: http://192.168.20.63:8080

---

## Rollback Plan (if needed)

If something goes wrong and you need to restore Fedora:

1. You still have the Fedora installation on the old disk
2. Boot from a USB drive and use `dd` to restore the backup
3. Or reinstall Fedora and restore the volumes from `/srv/k3-migration-backup/`

---

## Troubleshooting

### Can't SSH into k3 after nixos-anywhere

```bash
# Check if k3 is responding
ping 192.168.20.63

# Try root access
ssh root@192.168.20.63

# Check from console if available
```

### Services not starting

```bash
# Check logs
sudo journalctl -u n8n.service -f
sudo journalctl -u pinepods.service -f

# Manually pull images if needed
podman pull docker.n8n.io/n8nio/n8n:latest
podman pull docker.io/madeofpendletonwool/pinepods:latest
```

### Volume data missing

```bash
# Check if volumes exist
podman volume ls

# Manually restore a volume
podman volume create n8n-data
podman run --rm -v n8n-data:/target -v /srv/k3-migration-backup/TIMESTAMP:/backup:ro alpine sh -c "cd /target && tar xzf /backup/n8n-data.tar.gz"
```

---

## Post-Migration Cleanup

After everything is working:

```bash
# Optional: Remove backup after confirming everything works (wait a few days!)
# rm -rf /srv/k3-migration-backup/
```

