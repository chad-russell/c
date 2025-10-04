# Memos Quadlet Setup

This directory contains Podman Quadlet files for running Memos, a privacy-first, lightweight note-taking service.

## Architecture

- **Memos** - Lightweight note-taking web application with SQLite storage

## Files

- `memos.network` - Dedicated network for Memos
- `memos-data.volume` - Memos data persistence (SQLite database and assets)
- `memos.container` - Main Memos application

## Installation

### 1. Enable User Service Persistence (IMPORTANT)

For rootless Podman services to persist across logins, you must enable linger:

```bash
ssh your-machine 'loginctl enable-linger $USER'
```

Without this, services will stop when you log out!

### 2. Deploy with Your Tool

If you're using the homelab deployment tool:

```bash
# Add memos to your machine in machines/machines.yaml
# Then sync:
bun run src/index.ts sync k4
```

Or manually for rootless deployment:

```bash
mkdir -p ~/.config/containers/systemd/
cp services/memos/*.{container,network,volume} ~/.config/containers/systemd/
loginctl enable-linger $USER  # IMPORTANT: Enable service persistence
systemctl --user daemon-reload
systemctl --user start memos.service
systemctl --user enable memos.service
```

## Accessing Memos

Once running, access Memos at: **http://localhost:5230** (or http://k4:5230 if accessing remotely)

On first visit, you'll be prompted to set up your admin account.

## Managing Services

Check status:
```bash
systemctl --user status memos.service
```

View logs:
```bash
journalctl --user -u memos.service -f
```

Stop service:
```bash
systemctl --user stop memos.service
```

## Configuration Options

Edit `memos.container` to customize:

### Basic Settings
- **Port**: Change `PublishPort=5230:5230` if you need a different host port
- **Mode**: Set `MEMOS_MODE=prod` or `MEMOS_MODE=dev`

### Database Options

By default, Memos uses SQLite stored in `/var/opt/memos`. For production workloads or multi-instance setups, you can use PostgreSQL or MySQL:

#### PostgreSQL
```ini
Environment=MEMOS_DRIVER=postgres
Environment=MEMOS_DSN=postgresql://user:password@host:port/dbname
```

#### MySQL
```ini
Environment=MEMOS_DRIVER=mysql
Environment=MEMOS_DSN=user:password@tcp(host:port)/dbname
```

See [Memos Database Documentation](https://www.usememos.com/docs/install/database) for more details.

## Data Persistence

All data is stored in the named volume:
- `memos-data` - Memos SQLite database and uploaded assets

View volume:
```bash
podman volume ls | grep memos
```

Inspect volume:
```bash
podman volume inspect memos-data
```

## Updating Memos

To update to the latest version:

```bash
podman pull docker.io/neosmemo/memos:stable
systemctl --user restart memos.service
```

Or pin to a specific version by changing the image tag in `memos.container`:
```
Image=docker.io/neosmemo/memos:0.22.0
```

## Features

- **Privacy-First** - Self-hosted, your data stays with you
- **Lightweight** - Fast and efficient SQLite-based storage
- **Rich Markdown** - Full markdown support with preview
- **Tags & Organization** - Organize notes with tags and filters
- **Mobile Friendly** - Responsive design works on all devices
- **API Access** - RESTful API for integrations
- **Export** - Export your data anytime

## Troubleshooting

### Service won't start

Check if the image pulled successfully:
```bash
podman pull docker.io/neosmemo/memos:stable
```

### Can't access the web interface

Make sure:
1. The service is running: `systemctl --user status memos.service`
2. The port is not blocked by firewall
3. You're accessing the correct URL (http://k4:5230)

### Data not persisting

Verify the volume is mounted:
```bash
podman inspect memos | grep -A 10 Mounts
```

### Container logs

View container logs directly:
```bash
podman logs memos
journalctl --user -u memos.service -f
```

## References

- [Memos Official Website](https://www.usememos.com/)
- [Memos Documentation](https://www.usememos.com/docs)
- [Memos GitHub](https://github.com/usememos/memos)
- [Docker Installation Guide](https://www.usememos.com/docs/installation/docker)
- [Podman Quadlet Documentation](../../docs/quadlet.md)



