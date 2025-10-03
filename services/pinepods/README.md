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

## Installation

### For rootless (recommended)

1. Copy the quadlet files to your user systemd directory:
   ```bash
   mkdir -p ~/.config/containers/systemd/
   cp services/pinepods/*.{container,network,volume} ~/.config/containers/systemd/
   ```

2. Reload systemd to pick up the new units:
   ```bash
   systemctl --user daemon-reload
   ```

3. Start the services:
   ```bash
   systemctl --user start pinepods.service
   ```

4. Enable services to start on boot (requires loginctl enable-linger):
   ```bash
   loginctl enable-linger $USER
   systemctl --user enable pinepods.service
   ```

### For rootful

1. Copy the quadlet files to the system systemd directory:
   ```bash
   sudo cp services/pinepods/*.{container,network,volume} /etc/containers/systemd/
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

- **HOSTNAME**: The URL where you'll access PinePods (change from `http://localhost:8040`)
- **TZ**: Your timezone (currently `America/New_York`)
- **PUID/PGID**: User/Group IDs for file permissions (currently `911`)
- **Port**: Change `PublishPort=8040:8040` if you need a different host port

### Optional: Set Admin User

You can uncomment and add these to `pinepods.container` to create a default admin:
```
Environment=USERNAME=admin
Environment=PASSWORD=secure_password
Environment=FULLNAME=Admin User
Environment=EMAIL=admin@example.com
```

## Accessing PinePods

Once running, access PinePods at: http://localhost:8040

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

