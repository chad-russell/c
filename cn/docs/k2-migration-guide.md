# k2 Migration: Podman Quadlet → Docker OCI

## Overview
This guide walks you through migrating k2 from Podman quadlet to Docker OCI containers (matching k3/k4 setup).

## What Changed
- **karakeep.nix**: Converted from quadlet to Docker OCI
- **memos.nix**: Converted from quadlet to Docker OCI  
- **ntfy.nix**: Converted from quadlet to Docker OCI
- **papra.nix**: Converted from quadlet to Docker OCI
- **k2/configuration.nix**: Changed backend from "podman" to "docker"
- **Backup script**: Created `/cn/scripts/docker-backup.sh` for manual backup/restore

## Migration Steps

### 1. Backup Current Podman Volumes

```bash
# SSH into k2
ssh k2

# Create backup directory
sudo mkdir -p /tmp/podman-backup

# Backup each service's volumes
cd /tmp/podman-backup

# Karakeep
sudo bash -c 'podman volume export karakeep-app-data > karakeep-app-data.tar'
sudo bash -c 'podman volume export karakeep-data > karakeep-data.tar'
sudo bash -c 'podman volume export karakeep-homedash-config > karakeep-homedash-config.tar'

# Memos
sudo bash -c 'podman volume export memos-data > memos-data.tar'

# Ntfy
sudo bash -c 'podman volume export ntfy-config > ntfy-config.tar'
sudo bash -c 'podman volume export ntfy-cache > ntfy-cache.tar'

# Papra
sudo bash -c 'podman volume export papra-data > papra-data.tar'

# Verify backups were created
ls -lh *.tar
```

### 2. Stop Podman Containers

```bash
# Stop all containers
sudo systemctl stop karakeep.service
sudo systemctl stop karakeep-meilisearch.service
sudo systemctl stop karakeep-homedash.service
sudo systemctl stop karakeep-chrome.service
sudo systemctl stop memos.service
sudo systemctl stop ntfy.service
sudo systemctl stop papra.service
```

### 3. Deploy New Docker Configuration

```bash
# From your local machine, rebuild k2
cd ~/Code/c/cn
sudo nixos-rebuild switch --flake .#k2 --target-host k2
```

### 4. Restore Data to Docker Volumes

```bash
# SSH back into k2
ssh k2

# Stop Docker containers first
sudo systemctl stop docker-karakeep.service
sudo systemctl stop docker-karakeep-meilisearch.service
sudo systemctl stop docker-karakeep-homedash.service
sudo systemctl stop docker-memos.service
sudo systemctl stop docker-ntfy.service
sudo systemctl stop docker-papra.service

# Restore volumes
cd /tmp/podman-backup

# Karakeep
cat karakeep-app-data.tar | sudo docker run --rm -i -v karakeep-app-data:/data alpine sh -c "cd /data && tar xf -"
cat karakeep-data.tar | sudo docker run --rm -i -v karakeep-data:/data alpine sh -c "cd /data && tar xf -"
cat karakeep-homedash-config.tar | sudo docker run --rm -i -v karakeep-homedash-config:/data alpine sh -c "cd /data && tar xf -"

# Memos
cat memos-data.tar | sudo docker run --rm -i -v memos-data:/data alpine sh -c "cd /data && tar xf -"

# Ntfy
cat ntfy-config.tar | sudo docker run --rm -i -v ntfy-config:/data alpine sh -c "cd /data && tar xf -"
cat ntfy-cache.tar | sudo docker run --rm -i -v ntfy-cache:/data alpine sh -c "cd /data && tar xf -"

# Papra
cat papra-data.tar | sudo docker run --rm -i -v papra-data:/data alpine sh -c "cd /data && tar xf -"

# Start Docker containers
sudo systemctl start docker-karakeep.service
sudo systemctl start docker-karakeep-meilisearch.service
sudo systemctl start docker-karakeep-homedash.service
sudo systemctl start docker-memos.service
sudo systemctl start docker-ntfy.service
sudo systemctl start docker-papra.service
```

### 5. Verify Services

```bash
# Check container status
sudo docker ps

# Check service logs
sudo journalctl -u docker-karakeep.service -n 50
sudo journalctl -u docker-memos.service -n 50
sudo journalctl -u docker-ntfy.service -n 50
sudo journalctl -u docker-papra.service -n 50

# Test web interfaces
curl http://localhost:3322  # Karakeep
curl http://localhost:5230  # Memos
curl http://localhost:8090  # Ntfy
curl http://localhost:1221  # Papra
```

### 6. Verify Backups

```bash
# Check backup timer
systemctl list-timers | grep container-backup

# Test a backup manually
sudo systemctl start container-backup-memos.service
sudo journalctl -u container-backup-memos.service -n 50

# Verify backup files
ls -l /mnt/backups/containers/memos/
```

### 7. Cleanup (Optional)

```bash
# Once everything is verified working, clean up Podman volumes
sudo podman volume rm karakeep-app-data karakeep-data karakeep-homedash-config
sudo podman volume rm memos-data
sudo podman volume rm ntfy-config ntfy-cache
sudo podman volume rm papra-data

# Remove backup files
sudo rm -rf /tmp/podman-backup
```

## Using the Backup Script

The backup script is located at `/cn/scripts/docker-backup.sh`.

### Manual Backup
```bash
sudo /cn/scripts/docker-backup.sh backup memos memos-data
```

### Manual Restore
```bash
sudo /cn/scripts/docker-backup.sh restore memos /mnt/backups/containers/memos
```

## Troubleshooting

### 502 Bad Gateway from Caddy

If you're getting 502 Bad Gateway errors after migration, check the following:

#### 1. Verify ports are listening on the host
```bash
# Check if services are listening on the expected ports
sudo ss -tlnp | grep -E '3322|5230|8090|8595|1221'

# You should see output like:
# LISTEN 0      4096         0.0.0.0:3322       0.0.0.0:*    users:(("docker-proxy",pid=...))
# LISTEN 0      4096         0.0.0.0:5230       0.0.0.0:*    users:(("docker-proxy",pid=...))
# etc.
```

#### 2. Check Docker port bindings
```bash
# Verify Docker containers have correct port mappings
sudo docker ps --format "table {{.Names}}\t{{.Ports}}"

# Expected output:
# karakeep        0.0.0.0:3322->3000/tcp
# memos           0.0.0.0:5230->5230/tcp
# ntfy            0.0.0.0:8090->80/tcp
# karakeep-homedash  0.0.0.0:8595->8595/tcp
# papra           0.0.0.0:1221->1221/tcp
```

#### 3. Test local connectivity
```bash
# Test if services respond locally
curl -v http://localhost:3322  # Karakeep
curl -v http://localhost:5230  # Memos
curl -v http://localhost:8090  # Ntfy
curl -v http://localhost:8595  # Karakeep-homedash
curl -v http://localhost:1221  # Papra

# If these work but Caddy still gives 502, reload Caddy:
cd ~/caddy
docker compose restart
```

#### 4. Check if IPv6 is causing issues
If ports show as `:::PORT` instead of `0.0.0.0:PORT`, Docker might be binding to IPv6 only. Fix by restarting Docker:

```bash
sudo systemctl restart docker
# Wait a few seconds for containers to restart
sudo docker ps
```

#### 5. Verify Caddy can reach the host
```bash
# From inside the Caddy container
docker exec -it caddy-proxy sh
apk add curl
curl -v http://192.168.20.62:3322
exit
```

### Containers won't start
```bash
# Check Docker service
sudo systemctl status docker

# Check network creation
sudo docker network ls | grep -E 'karakeep|memos|ntfy|papra'

# Manually create network if missing
sudo docker network create karakeep
```

### Data missing after migration
```bash
# List Docker volumes
sudo docker volume ls

# Inspect a volume
sudo docker volume inspect memos-data

# Re-run restore for specific service
cat /tmp/podman-backup/memos-data.tar | sudo docker run --rm -i -v memos-data:/data alpine sh -c "cd /data && tar xf -"
```

### Backup service fails
```bash
# Check logs
sudo journalctl -u container-backup-memos.service -n 100

# Verify NFS mount
ls -l /mnt/backups/

# Test manual backup
sudo systemctl start container-backup-memos.service
```
