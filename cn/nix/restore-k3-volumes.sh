#!/usr/bin/env bash
# Restore script for k3 Podman volumes after NixOS migration
# Run this script ON k3 after NixOS installation as the crussell user

set -e

BACKUP_DIR="/srv/k3-migration-backup"

if [ -z "$1" ]; then
    echo "Usage: $0 <timestamp>"
    echo ""
    echo "Available backups:"
    ls -1 "${BACKUP_DIR}" 2>/dev/null || echo "  No backups found"
    exit 1
fi

TIMESTAMP="$1"
BACKUP_PATH="${BACKUP_DIR}/${TIMESTAMP}"

if [ ! -d "${BACKUP_PATH}" ]; then
    echo "Error: Backup not found at ${BACKUP_PATH}"
    exit 1
fi

echo "=================================================="
echo "K3 Volume Restore Script"
echo "=================================================="
echo "Restoring from: ${BACKUP_PATH}"
echo ""

# Show manifest if it exists
if [ -f "${BACKUP_PATH}/MANIFEST.txt" ]; then
    cat "${BACKUP_PATH}/MANIFEST.txt"
    echo ""
fi

# Stop all services first
echo "Stopping all services..."
sudo systemctl stop n8n.service pinepods.service pinepods-db.service pinepods-valkey.service searxng.service searxng-valkey.service 2>/dev/null || true
sleep 5
echo ""

# Find all backup tarballs
for backup_file in "${BACKUP_PATH}"/*.tar.gz; do
    if [ -f "${backup_file}" ]; then
        vol_name=$(basename "${backup_file}" .tar.gz)
        
        echo "Restoring volume: ${vol_name}"
        
        # Create the volume if it doesn't exist
        podman volume exists "${vol_name}" || podman volume create "${vol_name}"
        
        # Restore the data
        podman run --rm \
            -v "${vol_name}:/target" \
            -v "${BACKUP_PATH}:/backup:ro" \
            docker.io/library/alpine:latest \
            sh -c "cd /target && tar xzf /backup/${vol_name}.tar.gz"
        
        echo "  ✓ Restored ${vol_name}"
        echo ""
    fi
done

echo "=================================================="
echo "Restore Complete!"
echo "=================================================="
echo ""
echo "Starting services..."
sudo systemctl start n8n.service pinepods.service searxng.service
echo ""
echo "Checking service status..."
sleep 5
sudo systemctl status n8n.service pinepods.service searxng.service --no-pager
echo ""
echo "Restoration complete! Your services should now be running with restored data."

