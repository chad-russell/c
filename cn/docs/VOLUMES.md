# Volume Backup & Migration

This document describes how to backup and migrate Podman volumes between machines.

## Overview

When deploying services, Podman creates named volumes (e.g., `pinepods-pgdata`) to store persistent data. When moving a service to a new machine, you'll want to migrate this data.

## Manual Backup Process (MVP)

For now, volume backup/restore is a manual process. Automated backup commands will be added in Phase 3.

### 1. Backup Volumes on Source Machine

```bash
# SSH to the source machine
ssh source-machine

# Export each volume to a tarball
podman volume export volume-name --output ~/volume-name.tar

# Example for pinepods:
podman volume export pinepods-pgdata --output ~/pinepods-pgdata.tar
podman volume export pinepods-downloads --output ~/pinepods-downloads.tar
podman volume export pinepods-backups --output ~/pinepods-backups.tar
```

### 2. Transfer Backups

Copy the tarball(s) to your local machine or directly to the target machine:

```bash
# To local machine
scp source-machine:~/*.tar ./backups/

# Or directly between machines
scp source-machine:~/pinepods-*.tar target-machine:~/
```

### 3. Restore Volumes on Target Machine

```bash
# SSH to target machine
ssh target-machine

# Import each volume
podman volume import volume-name ./volume-name.tar

# Example for pinepods:
podman volume import pinepods-pgdata ./pinepods-pgdata.tar
podman volume import pinepods-downloads ./pinepods-downloads.tar
podman volume import pinepods-backups ./pinepods-backups.tar
```

### 4. Deploy Service

Once volumes are restored, deploy the service normally:

```bash
bun run deploy target-machine --service servicename
```

The deployment will:
1. Create volume quadlets (which reference the existing volumes)
2. Start containers that mount those volumes
3. Data from your backup will be available immediately

## Important Notes

### Volume Names Must Match

Ensure the volume names in your `.volume` quadlet files match the names you used when importing. For example, if your quadlet has:

```ini
[Volume]
VolumeName=pinepods-pgdata
```

You must import with:
```bash
podman volume import pinepods-pgdata ./pinepods-pgdata.tar
```

### Pre-existing Volumes

If you import volumes before deploying, the deployment will simply reference the existing volumes. Podman won't overwrite them.

### Data Loss Prevention

**Always backup volumes before:**
- Undeploying a service
- Migrating to a new machine  
- Major version upgrades

## Future Enhancements (Planned)

### Phase 2: Backup Commands

```bash
# Backup service volumes (planned)
bun run backup <machine> --service <service>

# Deploy with restore (planned)
bun run deploy <machine> --service <service> --restore-from backups/
```

### Phase 3: Automated Backups

- Scheduled backups
- Incremental backups with rsync
- Automatic pre-deployment backups
- Centralized backup storage

## Example: Migrating PinePods

Complete example of moving pinepods from `old-server` to `new-server`:

```bash
# 1. Backup on old server
ssh old-server
podman volume export pinepods-pgdata --output ~/pinepods-pgdata.tar
podman volume export pinepods-downloads --output ~/pinepods-downloads.tar
podman volume export pinepods-backups --output ~/pinepods-backups.tar
exit

# 2. Transfer to new server
scp old-server:~/pinepods-*.tar new-server:~/

# 3. Restore on new server
ssh new-server
podman volume import pinepods-pgdata ./pinepods-pgdata.tar
podman volume import pinepods-downloads ./pinepods-downloads.tar
podman volume import pinepods-backups ./pinepods-backups.tar
exit

# 4. Update machines.yaml
# Remove pinepods from old-server's services list
# Add pinepods to new-server's services list

# 5. Deploy
bun run deploy new-server

# 6. Verify
ssh new-server
systemctl --user status pinepods
podman ps
```

## Troubleshooting

### Volume Already Exists

If you get "volume already exists" when importing:

```bash
# Check existing volumes
podman volume ls

# Remove if needed (WARNING: deletes data)
podman volume rm volume-name

# Then import
podman volume import volume-name ./backup.tar
```

### Permission Issues

Volumes are owned by specific UIDs/GIDs. If you get permission errors:

1. Check the `PUID` and `PGID` in your container quadlets
2. Ensure they match between machines
3. Or adjust volume ownership after import:

```bash
podman unshare chown -R UID:GID ~/.local/share/containers/storage/volumes/volume-name
```

### Large Volumes

For very large volumes, consider using rsync instead of tar:

```bash
# On source machine, find volume mount point
podman volume inspect volume-name | grep Mountpoint

# Rsync directly
rsync -avz --progress \
  ~/.local/share/containers/storage/volumes/volume-name/_data/ \
  new-server:~/.local/share/containers/storage/volumes/volume-name/_data/
```

## See Also

- [Podman Volume Documentation](https://docs.podman.io/en/latest/markdown/podman-volume.1.html)
- [PLAN.md](../PLAN.md) - Roadmap for automated backups

