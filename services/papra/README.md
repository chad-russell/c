# Papra Quadlet Setup

This directory contains Podman Quadlet files for running Papra, a document management system.

## Overview

Papra is a self-hosted document management solution for organizing and managing your documents.

## Files

- `papra.network` - Dedicated network for Papra
- `papra-data.volume` - Papra data persistence (database and documents)
- `papra.container` - Main Papra application

## Installation

### 1. Enable User Service Persistence (If Not Already Done)

For rootless Podman services to persist across logins:

```bash
ssh k4 'loginctl enable-linger $USER'
```

### 2. Deploy with Your Tool

```bash
# Add papra to k4 in machines/machines.yaml
# Then sync:
bun run src/index.ts sync k4
```

Or manually:

```bash
mkdir -p ~/.config/containers/systemd/
cp services/papra/*.{container,network,volume} ~/.config/containers/systemd/
systemctl --user daemon-reload
systemctl --user start papra.service
systemctl --user enable papra.service
```

## Accessing Papra

Once running, access Papra at: **http://k4:1221**

On first visit, you'll set up your admin account.

## Managing Services

Check status:
```bash
systemctl --user status papra.service
```

View logs:
```bash
journalctl --user -u papra.service -f
```

Stop service:
```bash
systemctl --user stop papra.service
```

## Data Backup & Migration

### Understanding the Data Structure

Papra stores all data in a single volume:
```
papra-data/
├── db/         # SQLite database
└── documents/  # Uploaded documents
```

### Option 1: Export Volume to Tarball

**Backup:**
```bash
# On k4
podman volume export papra-data -o papra-backup-$(date +%Y%m%d).tar

# Copy to your local machine or NAS
scp crussell@k4:~/papra-backup-*.tar /path/to/backup/location/
```

**Restore:**
```bash
# Stop Papra first
systemctl --user stop papra.service

# Remove old volume (if restoring)
podman volume rm papra-data

# Import backup
podman volume import papra-data papra-backup-YYYYMMDD.tar

# Start Papra
systemctl --user start papra.service
```

### Option 2: Mount and Backup Directly

You can also backup by mounting the volume and copying files:

```bash
# Stop Papra first (recommended)
systemctl --user stop papra.service

# Get volume mount point
VOLUME_PATH=$(podman volume inspect papra-data --format '{{.Mountpoint}}')

# Backup to tarball
tar -czf papra-backup-$(date +%Y%m%d).tar.gz -C "$VOLUME_PATH" .

# Copy to NAS or backup location
cp papra-backup-*.tar.gz /path/to/backup/

# Start Papra again
systemctl --user start papra.service
```

### Option 3: Automated Backup Script

Create a backup script at `~/bin/backup-papra.sh`:

```bash
#!/bin/bash
# Automated Papra backup script

BACKUP_DIR="$HOME/backups/papra"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="papra-backup-${TIMESTAMP}.tar"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Export volume
podman volume export papra-data -o "$BACKUP_DIR/$BACKUP_FILE"

# Compress
gzip "$BACKUP_DIR/$BACKUP_FILE"

# Keep only last 7 backups
cd "$BACKUP_DIR"
ls -t papra-backup-*.tar.gz | tail -n +8 | xargs -r rm

echo "Backup completed: $BACKUP_DIR/$BACKUP_FILE.gz"
```

Make it executable:
```bash
chmod +x ~/bin/backup-papra.sh
```

Schedule with cron (daily at 2 AM):
```bash
crontab -e
# Add this line:
0 2 * * * /home/crussell/bin/backup-papra.sh
```

### Backup to NAS (If Available)

If you have a NAS mounted on k4, modify the backup script to copy to NAS:

```bash
# After creating backup
BACKUP_FILE="papra-backup-${TIMESTAMP}.tar.gz"
NAS_PATH="/mnt/backups/papra"

# Copy to NAS
cp "$BACKUP_DIR/$BACKUP_FILE" "$NAS_PATH/"
```

## Configuration Options

Edit `papra.container` to customize:

### Basic Settings
- **Port**: Change `PublishPort=1221:1221` if needed

### Environment Variables

Uncomment and configure in `papra.container`:

```ini
# Logging
Environment=PAPRA_LOG_LEVEL=info

# File upload size limit
Environment=PAPRA_MAX_UPLOAD_SIZE=50MB

# Timezone
Environment=TZ=America/New_York
```

See [Papra Configuration Docs](https://docs.papra.tech/configuration) for all available options.

## Data Persistence

All data is stored in the named volume:
- `papra-data` - SQLite database and uploaded documents

View volume:
```bash
podman volume ls | grep papra
```

Inspect volume:
```bash
podman volume inspect papra-data
```

Get volume size:
```bash
podman volume inspect papra-data --format '{{.Mountpoint}}' | xargs du -sh
```

## Updating Papra

To update to the latest version:

```bash
podman pull ghcr.io/papra-hq/papra:latest
systemctl --user restart papra.service
```

Check current version:
```bash
podman inspect papra --format '{{.Config.Image}}'
```

## Troubleshooting

### Service won't start

Check if the image pulled successfully:
```bash
podman pull ghcr.io/papra-hq/papra:latest
```

Check logs:
```bash
journalctl --user -u papra.service -n 50
```

### Can't access the web interface

Verify:
1. Service is running: `systemctl --user status papra.service`
2. Port is accessible: `curl http://localhost:1221`
3. Firewall allows connections

### File upload issues

Check volume permissions:
```bash
podman volume inspect papra-data --format '{{.Mountpoint}}' | xargs ls -la
```

With rootless Podman, files are owned by your user automatically.

### Database corruption

If the database becomes corrupted:
1. Stop Papra: `systemctl --user stop papra.service`
2. Restore from backup (see Backup section)
3. Start Papra: `systemctl --user start papra.service`

### Container logs

View container logs directly:
```bash
podman logs papra
podman logs papra --tail 50 -f
```

## Migration from Docker

If migrating from Docker to Podman:

1. **Export data from Docker:**
   ```bash
   # In your Docker directory
   docker compose down
   tar -czf papra-data-export.tar.gz ./app-data/
   ```

2. **Copy to k4:**
   ```bash
   scp papra-data-export.tar.gz crussell@k4:~/
   ```

3. **Import to Podman volume:**
   ```bash
   # On k4
   # Deploy Papra first (creates the volume)
   # Then stop it
   systemctl --user stop papra.service
   
   # Get volume path and extract
   VOLUME_PATH=$(podman volume inspect papra-data --format '{{.Mountpoint}}')
   tar -xzf papra-data-export.tar.gz -C "$VOLUME_PATH" --strip-components=1
   
   # Start Papra
   systemctl --user start papra.service
   ```

## Features

- 📄 **Document Management** - Organize and categorize documents
- 🔍 **Full-Text Search** - Find documents quickly
- 🏷️ **Tagging System** - Flexible organization
- 📱 **Responsive UI** - Works on all devices
- 🔒 **Self-Hosted** - Your data stays with you
- 🗄️ **SQLite Database** - Simple, reliable storage

## References

- [Papra Documentation](https://docs.papra.tech/)
- [Papra GitHub](https://github.com/papra-hq/papra)
- [Docker Installation Guide](https://docs.papra.tech/installation/docker)
- [Configuration Options](https://docs.papra.tech/configuration)
- [Podman Quadlet Documentation](../../docs/quadlet.md)
- [Volume Backup Guide](../../docs/VOLUMES.md)



