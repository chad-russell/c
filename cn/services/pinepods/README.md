# PinePods Quadlet Setup

This directory contains Podman Quadlet files for running PinePods, a Rust-based podcast management system.

## Architecture

- **PostgreSQL 17** - Database backend
- **Valkey 8** - Redis-compatible cache
- **PinePods** - Main application

## Files

- `pinepods.network` - Dedicated network for PinePods services
- `pinepods-pgdata.volume` - PostgreSQL data persistence
- `pinepods-downloads.volume` - Podcast downloads storage
- `pinepods-backups.volume` - Backup storage
- `pinepods-db.container` - PostgreSQL container
- `pinepods-valkey.container` - Valkey cache container
- `pinepods.container` - Main PinePods application

## Prerequisites

- Your reverse proxy must handle HTTPS/TLS termination
- Domain: `pinepods.internal.crussell.io` pointing to k3:8040

## Installation

### Step 1: Enable User Service Persistence

```bash
ssh k3 'loginctl enable-linger $USER'
```

### Step 2: Deploy the Service

Using the deployment tool:

```bash
# Add pinepods to k3 in machines/machines.yaml
# Then sync:
bun run src/index.ts sync k3
```

Or manually for rootless deployment:

```bash
mkdir -p ~/.config/containers/systemd/
cp services/pinepods/*.{container,network,volume} ~/.config/containers/systemd/
loginctl enable-linger $USER  # IMPORTANT: Enable service persistence
systemctl --user daemon-reload
systemctl --user start pinepods.service
systemctl --user enable pinepods.service
```

### Step 3: Configure Reverse Proxy

Point `pinepods.internal.crussell.io` to `k3:8040` in your Caddy configuration:

```
pinepods.internal.crussell.io {
    reverse_proxy k3:8040
}
```

### For rootful

1. Copy the quadlet files to the system systemd directory:
   ```bash
   sudo cp services/pinepods/*.{container,network,volume} ~/.config/containers/systemd/
   ```

2. Reload systemd:
   ```bash
   sudo systemctl daemon-reload
   ```

3. Start and enable the services:
   ```bash
   sudo systemctl start pinepods.service
   sudo systemctl enable pinepods.service
   ```

## Configuration

### Important: Change Default Password

**Before deploying to production**, you should change the default PostgreSQL password in both:
- `pinepods-db.container` - `POSTGRES_PASSWORD` variable
- `pinepods.container` - `DB_PASSWORD` variable

### Customization Options

Edit `pinepods.container` to customize:

- **HOSTNAME**: The URL where you'll access PinePods (currently `https://pinepods.internal.crussell.io`)
- **TZ**: Your timezone (currently `America/New_York`)
- **PUID/PGID**: User/Group IDs for file permissions (currently `911`)
- **Port**: Change `PublishPort=8040:8040` if you need a different host port (remember to update reverse proxy too)

### Optional: Set Admin User

You can uncomment and add these to `pinepods.container` to create a default admin:
```
Environment=USERNAME=admin
Environment=PASSWORD=secure_password
Environment=FULLNAME=Admin User
Environment=EMAIL=admin@example.com
```

## Accessing PinePods

Once running and your reverse proxy is configured, access PinePods at: **https://pinepods.internal.crussell.io**

On first boot (without admin environment variables), you'll be prompted to create an admin account.

## Managing Services

Check status:
```bash
systemctl --user status pinepods.service
systemctl --user status pinepods-db.service
systemctl --user status pinepods-valkey.service
```

View logs:
```bash
journalctl --user -u pinepods.service -f
journalctl --user -u pinepods-db.service -f
```

Stop services:
```bash
systemctl --user stop pinepods.service
```

## Data Persistence

All data is stored in named volumes:
- `pinepods-pgdata` - Database data
- `pinepods-downloads` - Downloaded podcasts
- `pinepods-backups` - Backups

View volumes:
```bash
podman volume ls
```

Inspect a volume:
```bash
podman volume inspect pinepods-pgdata
```

## Troubleshooting

### Service won't start

Check if the image pulled successfully:
```bash
podman pull docker.io/madeofpendletonwool/pinepods:latest
podman pull docker.io/library/postgres:17
podman pull docker.io/valkey/valkey:8-alpine
```

### Debug generated systemd files

View what Quadlet generated:
```bash
/usr/lib/systemd/system-generators/podman-system-generator --user --dryrun
```

Or for specific service:
```bash
systemd-analyze --user verify pinepods.service
```

### Container logs

View container logs directly:
```bash
podman logs pinepods
podman logs pinepods-db
podman logs pinepods-valkey
```

## References

- [PinePods Documentation](https://www.pinepods.online/docs/intro)
- [Podman Quadlet Documentation](../../docs/quadlet.md)

