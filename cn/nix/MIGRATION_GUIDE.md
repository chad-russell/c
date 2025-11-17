# Migration Guide: k4 (Podman/Quadlet) → k2 (NixOS)

This guide helps you migrate your Karakeep, Memos, and Papra services from your homegrown Podman/Quadlet setup on k4 to a declarative NixOS configuration on k2.

## Overview

### What Changed
- **Before**: Manual `.container`, `.volume`, and `.network` files in `/etc/containers/systemd/`
- **After**: Declarative NixOS modules in `/etc/nixos/services/`
- **Benefit**: Version-controlled, reproducible, atomic deployments

### Services Being Migrated
1. **Karakeep** - Bookmark manager (4 containers + 3 volumes + 1 network)
2. **Memos** - Note-taking service (1 container + 1 volume + 1 network)
3. **Papra** - Document management (1 container + 1 volume + 1 network)

## Prerequisites

### On k4 (Source)
1. Ensure all services are running properly
2. Identify data volume locations:
   ```bash
   podman volume inspect karakeep-app-data karakeep-data karakeep-homedash-config
   podman volume inspect memos-data
   podman volume inspect papra-data
   ```

### On k2 (Destination)
1. NixOS installed and accessible
2. SSH access configured
3. Sufficient disk space for volumes

## Migration Steps

### Step 1: Prepare k2 NixOS Configuration

The configuration is already set up in this repository:

```
nix/
├── flake.nix                    
├── configuration.nix            # Updated to import service modules
└── services/
    ├── karakeep.nix            # Karakeep service definition
    ├── memos.nix               # Memos service definition
    └── papra.nix               # Papra service definition
```

### Step 2: Review and Customize Service Configurations

Before deploying, review each service module and update the following:

#### Karakeep (`services/karakeep.nix`)
- [x] `NEXTAUTH_SECRET` - Generate new: `openssl rand -base64 36`
- [x] `NEXTAUTH_URL` - Update to k2's URL
- [x] `MEILI_MASTER_KEY` - Generate new: `openssl rand -base64 36`
- [x] `KARAKEEP_URL` - Update HomeDash URL reference

#### Memos (`services/memos.nix`)
- [x] Port configuration (default: 5230)
- [x] Optional: Database configuration if using PostgreSQL/MySQL

#### Papra (`services/papra.nix`)
- [x] `APP_BASE_URL` - Update to k2's URL
- [x] `TZ` - Verify timezone (currently: America/New_York)

### Step 3: Update flake.lock

On your local machine (where you have this repo):

```bash
cd /Users/chadrussell/Code/c/nix
nix flake update
```

### Step 4: Build and Test Locally (Optional)

Test the configuration before deploying:

```bash
nixos-rebuild build --flake .#k2
```

### Step 5: Deploy to k2

Deploy the new configuration to k2:

```bash
# From your local machine
nixos-rebuild switch --flake .#k2 --target-host crussell@k2 --use-remote-sudo

# Or if you prefer to build locally and deploy:
nixos-rebuild switch --flake .#k2 --target-host crussell@k2 --build-host localhost --use-remote-sudo
```

### Step 6: Verify Services Started

SSH into k2 and verify the services:

```bash
ssh crussell@k2

# Check systemd services
sudo systemctl status karakeep.service
sudo systemctl status karakeep-chrome.service
sudo systemctl status karakeep-meilisearch.service
sudo systemctl status karakeep-homedash.service
sudo systemctl status memos.service
sudo systemctl status papra.service

# Check container status
sudo podman ps

# Check networks
sudo podman network ls

# Check volumes
sudo podman volume ls
```

### Step 7: Migrate Data from k4 to k2

Now that the containers are running on k2 (with empty volumes), migrate the data:

#### Option A: Volume Export/Import (Recommended)

On k4:
```bash
# Stop services first
systemctl --user stop karakeep karakeep-homedash memos papra

# Export volumes
podman volume export karakeep-app-data -o /tmp/karakeep-app-data.tar
podman volume export karakeep-data -o /tmp/karakeep-data.tar
podman volume export karakeep-homedash-config -o /tmp/karakeep-homedash-config.tar
podman volume export memos-data -o /tmp/memos-data.tar
podman volume export papra-data -o /tmp/papra-data.tar

# Transfer to k2
scp /tmp/*.tar crussell@k2:/tmp/
```

On k2:
```bash
# Stop services
sudo systemctl stop karakeep karakeep-homedash memos papra

# Import volumes
sudo podman volume import karakeep-app-data /tmp/karakeep-app-data.tar
sudo podman volume import karakeep-data /tmp/karakeep-data.tar
sudo podman volume import karakeep-homedash-config /tmp/karakeep-homedash-config.tar
sudo podman volume import memos-data /tmp/memos-data.tar
sudo podman volume import papra-data /tmp/papra-data.tar

# Start services
sudo systemctl start karakeep karakeep-homedash memos papra
```

#### Option B: Direct rsync (Alternative)

Find volume mount points and rsync:

On k4:
```bash
# Find volume paths
podman volume inspect karakeep-app-data | grep Mountpoint
# Example output: "Mountpoint": "/var/lib/containers/storage/volumes/karakeep-app-data/_data"
```

On k2:
```bash
# Stop services first
sudo systemctl stop karakeep karakeep-homedash memos papra

# Rsync each volume (run from k2)
sudo rsync -avz --progress crussell@k4:/var/lib/containers/storage/volumes/karakeep-app-data/_data/ \
  /var/lib/containers/storage/volumes/karakeep-app-data/_data/

sudo rsync -avz --progress crussell@k4:/var/lib/containers/storage/volumes/karakeep-data/_data/ \
  /var/lib/containers/storage/volumes/karakeep-data/_data/

sudo rsync -avz --progress crussell@k4:/var/lib/containers/storage/volumes/karakeep-homedash-config/_data/ \
  /var/lib/containers/storage/volumes/karakeep-homedash-config/_data/

sudo rsync -avz --progress crussell@k4:/var/lib/containers/storage/volumes/memos-data/_data/ \
  /var/lib/containers/storage/volumes/memos-data/_data/

sudo rsync -avz --progress crussell@k4:/var/lib/containers/storage/volumes/papra-data/_data/ \
  /var/lib/containers/storage/volumes/papra-data/_data/

# Start services
sudo systemctl start karakeep karakeep-homedash memos papra
```

### Step 8: Update DNS/Reverse Proxy

Update your DNS records or reverse proxy (Caddy/Nginx/Traefik) to point to k2:

- `karakeep.internal.crussell.io` → k2:3322
- `karakeep-homedash.internal.crussell.io` → k2:8595 (if exposed)
- `memos.internal.crussell.io` → k2:5230
- `papra.internal.crussell.io` → k2:1221

### Step 9: Verify Services

Test each service:

1. **Karakeep**: Visit https://karakeep.internal.crussell.io
   - Login with existing credentials
   - Verify bookmarks are present
   - Test adding a new bookmark
   - Test search functionality

2. **Karakeep HomeDash**: Visit http://k2:8595
   - Verify bookmarks display correctly
   - Test navigation

3. **Memos**: Visit https://memos.internal.crussell.io
   - Login with existing credentials
   - Verify notes are present
   - Test creating a new note

4. **Papra**: Visit https://papra.internal.crussell.io
   - Login with existing credentials
   - Verify documents are present
   - Test uploading a new document

### Step 10: Monitor and Verify

Monitor the services for a few days:

```bash
# View logs
journalctl -u karakeep -f
journalctl -u memos -f
journalctl -u papra -f

# Check resource usage
podman stats
```

### Step 11: Decommission k4 Services (Optional)

Once you're confident everything works on k2:

On k4:
```bash
# Stop and disable services
systemctl --user stop karakeep karakeep-homedash karakeep-meilisearch karakeep-chrome
systemctl --user stop memos papra
systemctl --user disable karakeep karakeep-homedash karakeep-meilisearch karakeep-chrome
systemctl --user disable memos papra

# Optional: Remove containers and volumes (CAREFUL!)
# podman rm -f karakeep karakeep-homedash karakeep-meilisearch karakeep-chrome memos papra
# podman volume rm karakeep-app-data karakeep-data karakeep-homedash-config memos-data papra-data
```

## Advantages of NixOS

### 1. Declarative Configuration
- All services defined in version-controlled Nix files
- Easy to review changes via git diff
- Reproducible across machines

### 2. Atomic Updates
- `nixos-rebuild` is atomic - either succeeds completely or rolls back
- Can rollback to previous generations: `nixos-rebuild switch --rollback`

### 3. Type Safety
- Nix language provides type checking
- Catches configuration errors before deployment

### 4. Modularity
- Each service in its own module
- Easy to enable/disable services
- Reusable across multiple machines

### 5. Integration with NixOS
- Services integrate with NixOS firewall, networking, etc.
- Consistent with rest of system configuration

## Troubleshooting

### Services Won't Start

Check systemd status:
```bash
systemctl status karakeep.service
journalctl -u karakeep.service -n 50
```

### Container Image Pull Failures

```bash
# Manually pull images
sudo podman pull ghcr.io/karakeep-app/karakeep:release
sudo podman pull docker.io/neosmemo/memos:stable
sudo podman pull ghcr.io/papra-hq/papra:latest
```

### Volume Permission Issues

```bash
# Check volume ownership
sudo ls -la /var/lib/containers/storage/volumes/karakeep-app-data/_data/

# Fix permissions if needed
sudo chown -R 1000:1000 /var/lib/containers/storage/volumes/karakeep-app-data/_data/
```

### Network Issues

```bash
# Verify networks exist
sudo podman network ls

# Recreate network if needed
sudo podman network rm karakeep
sudo systemctl restart karakeep-network.service
```

### Configuration Syntax Errors

```bash
# Check Nix syntax
nix flake check

# Build without switching
nixos-rebuild build --flake .#k2
```

## Making Changes After Migration

### Adding Environment Variables

Edit the service module (e.g., `services/karakeep.nix`):

```nix
environments = {
  EXISTING_VAR = "value";
  NEW_VAR = "new_value";  # Add this
};
```

Then rebuild:
```bash
nixos-rebuild switch --flake .#k2 --target-host crussell@k2 --use-remote-sudo
```

### Updating Container Images

Images are automatically updated when you change the `image` field:

```nix
image = "ghcr.io/karakeep-app/karakeep:v2.0.0";  # Change version
```

Or use `latest` tag and manually pull:
```bash
sudo podman pull ghcr.io/karakeep-app/karakeep:latest
sudo systemctl restart karakeep
```

### Adding New Services

1. Create a new module in `services/myservice.nix`
2. Add to `configuration.nix` imports
3. Rebuild and deploy

## Rollback Procedure

If something goes wrong:

```bash
# On k2, list generations
sudo nixos-rebuild list-generations

# Rollback to previous generation
sudo nixos-rebuild switch --rollback

# Or switch to specific generation
sudo nixos-rebuild switch --switch-generation 123
```

## Backup Strategy

### Automated Backups

Consider setting up automated volume backups:

```bash
# Example backup script
#!/usr/bin/env bash
BACKUP_DIR="/backup/podman-volumes"
DATE=$(date +%Y%m%d-%H%M%S)

sudo podman volume export karakeep-app-data -o "$BACKUP_DIR/karakeep-app-data-$DATE.tar"
sudo podman volume export memos-data -o "$BACKUP_DIR/memos-data-$DATE.tar"
sudo podman volume export papra-data -o "$BACKUP_DIR/papra-data-$DATE.tar"

# Keep only last 7 days
find "$BACKUP_DIR" -name "*.tar" -mtime +7 -delete
```

## Additional Resources

- [Podman Quadlet Documentation](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html)
- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Podman Documentation](https://docs.podman.io/)

## Support

If you encounter issues:

1. Check systemd logs: `journalctl -u <service-name>`
2. Check container logs: `podman logs <container-name>`
3. Verify configuration: `nix flake check`
4. Review this guide's troubleshooting section

## Summary

This migration moves your services from manual Quadlet files to declarative NixOS modules, providing:

- ✅ Version control for all service configurations
- ✅ Atomic deployments with rollback capability
- ✅ Type-safe configuration
- ✅ Reproducible across machines
- ✅ Integration with NixOS ecosystem

The migration preserves all your data and maintains the same container images and configurations, just managed in a more maintainable way.
