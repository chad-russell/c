# K3 Backup and Deploy Workflow

## Critical Information

⚠️ **IMPORTANT:** All data on k3 will be wiped during nixos-anywhere installation. We must backup first and copy to this local machine for safekeeping.

## Complete Workflow

### Step 1: Backup Volumes on k3

```bash
# Copy backup script to k3
scp backup-k3-volumes.sh crussell@192.168.20.63:~/

# SSH into k3 and run backup
ssh crussell@192.168.20.63

# Run backup (this saves to /tmp/k3-migration-backup/)
chmod +x ~/backup-k3-volumes.sh
~/backup-k3-volumes.sh

# Note the timestamp directory name - you'll need it!
# Example: 20241112_210530
```

### Step 2: Copy Backup to Local Machine

```bash
# From your local machine (exit k3 first)
exit  # Exit from k3 SSH session

# Copy the backup to your local machine for safekeeping
# Replace TIMESTAMP with the actual timestamp from Step 1
rsync -avz --progress crussell@192.168.20.63:/tmp/k3-migration-backup/ ./k3-backup/

# Verify the backup was copied
ls -lh ./k3-backup/TIMESTAMP/
cat ./k3-backup/TIMESTAMP/MANIFEST.txt
```

**CRITICAL VERIFICATION:**
Ensure these files exist and are non-zero size:
- `./k3-backup/TIMESTAMP/n8n-data.tar.gz`
- `./k3-backup/TIMESTAMP/pinepods-pgdata.tar.gz`

### Step 3: Deploy NixOS

```bash
# From /home/crussell/Code/c/cn/nix directory
cd /home/crussell/Code/c/cn/nix

# Run nixos-anywhere (this will WIPE k3)
nixos-anywhere --flake .#k3 root@192.168.20.63
```

**Wait for completion (~10-15 minutes)**

### Step 4: Copy Backup to New k3

```bash
# Wait ~2-3 minutes after nixos-anywhere completes for k3 to boot

# Copy backup to the new NixOS k3 (now it will go to /srv which is mounted)
rsync -avz --progress ./k3-backup/ crussell@192.168.20.63:/srv/k3-migration-backup/

# Verify it was copied
ssh crussell@192.168.20.63 "ls -lh /srv/k3-migration-backup/"
```

### Step 5: Restore Volumes

```bash
# Copy restore script to k3
scp restore-k3-volumes.sh crussell@192.168.20.63:~/

# SSH into k3
ssh crussell@192.168.20.63

# Run restore (use the TIMESTAMP from Step 1)
chmod +x ~/restore-k3-volumes.sh
~/restore-k3-volumes.sh TIMESTAMP
```

### Step 6: Verify Services

```bash
# Still on k3
sudo systemctl status n8n.service pinepods.service searxng.service

# Check containers
podman ps

# Test web access (from your browser)
```

- n8n: http://192.168.20.63:5678
- PinePods: http://192.168.20.63:8040
- SearXNG: http://192.168.20.63:8080

### Step 7: Cleanup (optional, after verifying everything works)

```bash
# Keep local backup safe for a while
# Keep the backup on k3 for a few days before removing:
# ssh crussell@192.168.20.63 "rm -rf /srv/k3-migration-backup/"
```

---

## Quick Reference Commands

```bash
# 1. Backup on k3
ssh crussell@192.168.20.63 './backup-k3-volumes.sh'

# 2. Copy to local
rsync -avz --progress crussell@192.168.20.63:/tmp/k3-migration-backup/ ./k3-backup/

# 3. Deploy NixOS
nixos-anywhere --flake .#k3 root@192.168.20.63

# 4. Copy backup back to new k3
rsync -avz --progress ./k3-backup/ crussell@192.168.20.63:/srv/k3-migration-backup/

# 5. Restore on k3
ssh crussell@192.168.20.63 './restore-k3-volumes.sh TIMESTAMP'
```

---

## Troubleshooting

### Backup too large to fit in /tmp

If you get "No space left on device" during backup:

```bash
# On k3, check space
df -h /tmp

# Alternative: Use /home instead
# Edit backup-k3-volumes.sh and change:
# BACKUP_DIR="/home/crussell/k3-migration-backup"
```

### rsync fails

```bash
# Test SSH connection first
ssh crussell@192.168.20.63 "echo Connection OK"

# Use alternative rsync with more verbose output
rsync -avzh --progress --stats crussell@192.168.20.63:/tmp/k3-migration-backup/ ./k3-backup/
```

### Can't SSH after nixos-anywhere

```bash
# Wait longer (up to 5 minutes)
# Check if host is up
ping 192.168.20.63

# Try root first
ssh root@192.168.20.63

# If that works, crussell should too
ssh crussell@192.168.20.63
```

