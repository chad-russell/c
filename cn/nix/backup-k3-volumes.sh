#!/bin/bash
# Backup script for k3 Podman volumes before NixOS migration
# Run this script ON k3 as the crussell user

set -e

BACKUP_DIR="/tmp/k3-migration-backup"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="${BACKUP_DIR}/${TIMESTAMP}"

echo "=================================================="
echo "K3 Volume Backup Script"
echo "=================================================="
echo "Backup location: ${BACKUP_PATH}"
echo ""

# Create backup directory
mkdir -p "${BACKUP_PATH}"

# List of volumes to backup (from the services we saw)
VOLUMES=(
    "n8n-data"
    "n8n-files"
    "pinepods-downloads"
    "pinepods-backups"
    "pinepods-pgdata"
    "searxng-config"
    "searxng-cache"
    "searxng-valkey-data"
)

echo "Volumes to backup:"
for vol in "${VOLUMES[@]}"; do
    echo "  - ${vol}"
done
echo ""

# Stop all containers to ensure data consistency
echo "Stopping all containers for consistent backup..."
systemctl --user stop pinepods.service pinepods-db.service pinepods-valkey.service n8n.service searxng.service searxng-valkey.service 2>/dev/null || true
sleep 5
echo "Containers stopped."
echo ""

# Backup each volume
for vol in "${VOLUMES[@]}"; do
    echo "Backing up volume: ${vol}"
    
    # Check if volume exists
    if podman volume exists "${vol}" 2>/dev/null; then
        # Create tarball of the volume
        podman run --rm \
            -v "${vol}:/source:ro" \
            -v "${BACKUP_PATH}:/backup" \
            docker.io/library/alpine:latest \
            tar czf "/backup/${vol}.tar.gz" -C /source .
        
        echo "  ✓ Backed up to: ${BACKUP_PATH}/${vol}.tar.gz"
        
        # Get size
        SIZE=$(du -sh "${BACKUP_PATH}/${vol}.tar.gz" | cut -f1)
        echo "  Size: ${SIZE}"
    else
        echo "  ⚠ Volume not found, skipping"
    fi
    echo ""
done

# Create a manifest file
echo "Creating backup manifest..."
cat > "${BACKUP_PATH}/MANIFEST.txt" <<EOF
K3 Volume Backup
================
Timestamp: ${TIMESTAMP}
Date: $(date)
Hostname: $(hostname)

Volumes backed up:
EOF

for vol in "${VOLUMES[@]}"; do
    if [ -f "${BACKUP_PATH}/${vol}.tar.gz" ]; then
        SIZE=$(du -sh "${BACKUP_PATH}/${vol}.tar.gz" | cut -f1)
        echo "  ${vol}.tar.gz (${SIZE})" >> "${BACKUP_PATH}/MANIFEST.txt"
    fi
done

cat >> "${BACKUP_PATH}/MANIFEST.txt" <<EOF

Restore Instructions:
=====================
After NixOS installation, run the restore script:
  ./restore-k3-volumes.sh ${TIMESTAMP}

EOF

echo "=================================================="
echo "Backup Complete!"
echo "=================================================="
echo "Backup location: ${BACKUP_PATH}"
echo ""
echo "Total backup size:"
du -sh "${BACKUP_PATH}"
echo ""
echo "IMPORTANT: Verify the backup before running nixos-anywhere!"
echo "  ls -lh ${BACKUP_PATH}"
echo ""
echo "To restart services (if not proceeding with migration):"
echo "  systemctl --user start pinepods.service n8n.service searxng.service"
echo ""

