# n8n Quadlet Setup

This directory contains Podman Quadlet files for running n8n, a powerful workflow automation platform.

## Overview

n8n (pronounced "n-eight-n") is a fair-code licensed workflow automation tool that lets you connect various services and automate tasks. It's self-hosted and extensible, with support for 400+ integrations.

## Architecture

- **n8n** - Workflow automation platform with built-in SQLite database

## Files

- `n8n.network` - Dedicated network for n8n
- `n8n-data.volume` - n8n data persistence (SQLite database and encryption key)
- `n8n-files.volume` - Local files for Read/Write Files from Disk node
- `n8n.container` - Main n8n application

## Installation

### Prerequisites

**IMPORTANT**: You need a reverse proxy configured to handle HTTPS/TLS termination before deploying n8n. n8n requires HTTPS for webhooks and OAuth to work properly.

### 1. Configure n8n Settings

Edit `n8n.container` and set:

**Required Settings:**
- **N8N_HOST**: Your n8n domain (e.g., `n8n.crussell.io`)
- **WEBHOOK_URL**: Your n8n webhook URL (e.g., `https://n8n.crussell.io/`)
- **GENERIC_TIMEZONE**: Your timezone (e.g., `America/New_York`, `Europe/Berlin`)

**Important**: The `N8N_HOST` and `WEBHOOK_URL` must match your reverse proxy configuration!

### 2. Set Up Reverse Proxy

Configure your reverse proxy (Caddy, Nginx, Traefik, etc.) to:
- Point your domain (e.g., `n8n.crussell.io`) to `k3:5678`
- Handle TLS/SSL termination
- Forward requests to n8n

Example Caddy configuration:
```
n8n.crussell.io {
    reverse_proxy k3:5678
}
```

Example Nginx configuration:
```nginx
server {
    listen 443 ssl http2;
    server_name n8n.crussell.io;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass http://k3:5678;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

### 3. Enable User Service Persistence (IMPORTANT)

For rootless Podman services to persist across logins, you must enable linger:

```bash
ssh k3 'loginctl enable-linger $USER'
```

Without this, services will stop when you log out!

### 4. Deploy with Your Tool

If you're using the homelab deployment tool:

```bash
# Add n8n to k3 in machines/machines.yaml
# Then sync:
bun run src/index.ts sync k3
```

Or manually for rootless deployment:

```bash
mkdir -p ~/.config/containers/systemd/
cp services/n8n/*.{container,network,volume} ~/.config/containers/systemd/
loginctl enable-linger $USER  # IMPORTANT: Enable service persistence
systemctl --user daemon-reload
systemctl --user start n8n.service
systemctl --user enable n8n.service
```

## Accessing n8n

Once running and your reverse proxy is configured, access n8n at: **https://n8n.crussell.io** (or your configured domain)

On first visit, you'll be prompted to create an owner account.

## Managing Services

Check status:
```bash
systemctl --user status n8n.service
```

View logs:
```bash
journalctl --user -u n8n.service -f
```

Stop service:
```bash
systemctl --user stop n8n.service
```

## Configuration Options

Edit `n8n.container` to customize:

### Required Settings
- **N8N_HOST**: Your n8n domain
- **N8N_PROTOCOL**: Should be `https` for production
- **WEBHOOK_URL**: Full webhook URL (must be HTTPS)
- **GENERIC_TIMEZONE**: Your timezone

### Optional Settings

#### Database
By default, n8n uses SQLite. For production with high workloads, consider PostgreSQL:
```ini
Environment=DB_TYPE=postgresdb
Environment=DB_POSTGRESDB_HOST=postgres
Environment=DB_POSTGRESDB_DATABASE=n8n
Environment=DB_POSTGRESDB_USER=n8n
Environment=DB_POSTGRESDB_PASSWORD=your_password
```

#### Email Notifications
```ini
Environment=N8N_EMAIL_MODE=smtp
Environment=N8N_SMTP_HOST=smtp.example.com
Environment=N8N_SMTP_PORT=587
Environment=N8N_SMTP_USER=your_email@example.com
Environment=N8N_SMTP_PASS=your_password
```

#### Execution Data Cleanup
```ini
Environment=EXECUTIONS_DATA_PRUNE=true
Environment=EXECUTIONS_DATA_MAX_AGE=336  # Hours (14 days)
```

#### Port
Change `PublishPort=5678:5678` if you need a different host port (update reverse proxy accordingly)

## Data Persistence

All data is stored in named volumes:
- `n8n-data` - SQLite database, encryption key, and configuration
- `n8n-files` - Files accessible via the Read/Write Files from Disk node

View volumes:
```bash
podman volume ls | grep n8n
```

Inspect volumes:
```bash
podman volume inspect n8n-data
podman volume inspect n8n-files
```

## Backup

To backup your n8n data:

```bash
# Export workflows via UI (Settings → Workflows)
# Or backup the entire data volume:
podman volume export n8n-data > n8n-data-backup.tar
```

To restore:
```bash
podman volume import n8n-data < n8n-data-backup.tar
```

See [Volume Backup & Migration docs](../../docs/VOLUMES.md) for more details.

## Updating n8n

To update to the latest version:

```bash
podman pull docker.n8n.io/n8nio/n8n:latest
systemctl --user restart n8n.service
```

Or pin to a specific version by changing the image tag in `n8n.container`:
```
Image=docker.n8n.io/n8nio/n8n:1.113.3
```

**Version Information:**
- `latest` - Production stable release
- `next` - Beta release (may be unstable)

Check current versions at [docs.n8n.io](https://docs.n8n.io/hosting/installation/docker/)

## Features

- **400+ Integrations** - Connect to popular services and APIs
- **Visual Workflow Editor** - Drag-and-drop workflow creation
- **Custom Code** - JavaScript and Python code execution
- **Webhooks** - Trigger workflows from external events
- **Scheduling** - Cron-based workflow scheduling
- **Error Handling** - Retry logic and error workflows
- **Variables & Expressions** - Dynamic data processing
- **Self-Hosted** - Your data stays on your infrastructure

## Troubleshooting

### Service won't start

Check if the image pulled successfully:
```bash
podman pull docker.n8n.io/n8nio/n8n:latest
```

### Can't access the web interface

Make sure:
1. The service is running: `systemctl --user status n8n.service`
2. Your reverse proxy is configured correctly
3. DNS points to your server
4. Firewall allows traffic on the reverse proxy ports (80/443)

### Webhooks not working

Verify:
1. `N8N_PROTOCOL=https` is set
2. `WEBHOOK_URL` matches your public URL
3. Your reverse proxy forwards requests correctly
4. The domain is accessible from the internet (for external webhooks)

### OAuth connections failing

n8n requires HTTPS for OAuth. Make sure:
1. Your reverse proxy handles SSL/TLS properly
2. `N8N_PROTOCOL=https` is set
3. `N8N_HOST` matches your actual domain

### Database errors

If switching from SQLite to PostgreSQL:
1. Export your workflows first (Settings → Workflows)
2. Change database configuration
3. Restart n8n
4. Re-import workflows

### Container logs

View container logs directly:
```bash
podman logs n8n
journalctl --user -u n8n.service -f
```

## Security Considerations

1. **Use HTTPS**: Required for webhooks and OAuth
2. **Strong passwords**: Set a strong owner account password
3. **Keep updated**: Regularly update n8n to get security patches
4. **Network access**: Consider restricting access via firewall or VPN
5. **Backup encryption key**: The encryption key in `/home/node/.n8n` is critical - back it up!

## References

- [n8n Official Documentation](https://docs.n8n.io/)
- [n8n GitHub](https://github.com/n8n-io/n8n)
- [Docker Installation Guide](https://docs.n8n.io/hosting/installation/docker/)
- [n8n Community Forum](https://community.n8n.io/)
- [Podman Quadlet Documentation](../../docs/quadlet.md)



