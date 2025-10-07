# SearXNG Quadlet Setup

This directory contains Podman Quadlet files for running SearXNG, a privacy-respecting metasearch engine.

## Overview

SearXNG is a free internet metasearch engine which aggregates results from various search services and databases. Users are neither tracked nor profiled.

## Architecture

- **SearXNG** - Main search application
- **Valkey** - In-memory cache (Redis-compatible)

## Files

- `searxng.network` - Dedicated network for SearXNG services
- `searxng-valkey-data.volume` - Valkey cache persistence
- `searxng-cache.volume` - SearXNG cache storage
- `searxng-config.volume` - Configuration files storage
- `searxng-valkey.container` - Valkey (Redis) cache service
- `searxng.container` - Main SearXNG application

## Prerequisites

- Your reverse proxy must handle HTTPS/TLS termination
- Domain: `searxng.internal.crussell.io` pointing to k2:8080

## Installation

### Step 1: Enable User Service Persistence

```bash
ssh k2 'loginctl enable-linger $USER'
```

### Step 2: Deploy the Service

```bash
# Add searxng to k2 in machines/machines.yaml
# Then sync:
bun run src/index.ts sync k2
```

Or manually:

```bash
mkdir -p ~/.config/containers/systemd/
cp services/searxng/*.{container,network,volume} ~/.config/containers/systemd/
systemctl --user daemon-reload
systemctl --user start searxng.service
systemctl --user enable searxng.service
```

The service will start with default configuration. SearXNG automatically initializes the config volume on first run.

### Step 3: Configure Reverse Proxy

Point `searxng.internal.crussell.io` to `k2:8080` in your Caddy configuration:

```
searxng.internal.crussell.io {
    reverse_proxy k2:8080
}
```

## Accessing SearXNG

Once deployed and reverse proxy configured:
- **URL**: https://searxng.internal.crussell.io

## Backup and Restore

Since all data is stored in named volumes, backup and restore are straightforward:

### Backup Configuration

```bash
# Export the config volume to a tar file
ssh k2 'podman volume export systemd-searxng-config -o /tmp/searxng-config-backup.tar'

# Download the backup
scp crussell@k2:/tmp/searxng-config-backup.tar ./backups/

# Clean up remote backup file
ssh k2 'rm /tmp/searxng-config-backup.tar'
```

### Restore Configuration

```bash
# Upload the backup
scp ./backups/searxng-config-backup.tar crussell@k2:/tmp/

# Import into the volume
ssh k2 'podman volume import systemd-searxng-config /tmp/searxng-config-backup.tar'

# Clean up
ssh k2 'rm /tmp/searxng-config-backup.tar'

# Restart service
ssh k2 'systemctl --user restart searxng.service'
```

### Full Backup (All Volumes)

```bash
# Backup all searxng volumes
for vol in config cache valkey-data; do
  ssh k2 "podman volume export systemd-searxng-$vol -o /tmp/searxng-$vol.tar"
  scp crussell@k2:/tmp/searxng-$vol.tar ./backups/
  ssh k2 "rm /tmp/searxng-$vol.tar"
done
```

## Managing Services

Check status:
```bash
systemctl --user status searxng.service
systemctl --user status searxng-valkey.service
```

View logs:
```bash
journalctl --user -u searxng.service -f
journalctl --user -u searxng-valkey.service -f
```

Stop services:
```bash
systemctl --user stop searxng.service
systemctl --user stop searxng-valkey.service
```

## Configuration

SearXNG automatically creates a default `settings.yml` in the config volume on first startup.

### Customizing Configuration

To customize SearXNG settings:

1. Export the current configuration:
```bash
ssh k2 'podman exec searxng cat /etc/searxng/settings.yml' > searxng-settings.yml
```

2. Edit the file locally with your preferred settings (see [SearXNG Settings Documentation](https://docs.searxng.org/admin/settings/index.html))

3. Copy the updated configuration back:
```bash
# Stop the service
ssh k2 'systemctl --user stop searxng.service'

# Update the config in the volume
cat searxng-settings.yml | ssh k2 'podman run --rm -i -v systemd-searxng-config:/config alpine tee /config/settings.yml > /dev/null'

# Restart the service
ssh k2 'systemctl --user start searxng.service'
```

### Important Settings

- **secret_key**: Auto-generated on first run. Change it for better security.
- **base_url**: Set via `SEARXNG_BASE_URL` environment variable in `searxng.container`
- **limiter**: Optional rate limiting (requires `limiter.toml` file)

See [Rate Limiter Documentation](https://docs.searxng.org/admin/settings/limiter.html).

### Customizing Search Engines

To enable/disable specific search engines, edit the settings.yml (see Configuration section above) and add an `engines:` section:

```yaml
engines:
  - name: google
    disabled: false
  - name: bing
    disabled: false
  - name: duckduckgo
    disabled: false
```

See [Engines Documentation](https://docs.searxng.org/admin/engines/index.html).

## Data Persistence

All data is stored in named volumes for easy backup and portability:
- `systemd-searxng-config` - Configuration files (settings.yml, limiter.toml)
- `systemd-searxng-valkey-data` - Valkey cache persistence
- `systemd-searxng-cache` - SearXNG search result cache

View volumes:
```bash
ssh k2 'podman volume ls | grep searxng'
```

Inspect volumes:
```bash
ssh k2 'podman volume inspect systemd-searxng-config'
ssh k2 'podman volume inspect systemd-searxng-valkey-data'
ssh k2 'podman volume inspect systemd-searxng-cache'
```

## Backup

### Configuration Files
```bash
# On k2
tar -czf searxng-config-backup-$(date +%Y%m%d).tar.gz ~/.config/searxng/

# Copy to safe location
scp crussell@k2:~/searxng-config-backup-*.tar.gz /path/to/backup/
```

### Valkey Cache (Optional)
The cache can be regenerated, but if you want to backup:
```bash
podman volume export searxng-valkey-data -o searxng-valkey-backup.tar
```

## Updating SearXNG

To update to the latest version:

```bash
# On k2 or via deployment tool
podman pull docker.io/searxng/searxng:latest
podman pull docker.io/valkey/valkey:8-alpine
systemctl --user restart searxng.service
systemctl --user restart searxng-valkey.service
```

Or via your deployment tool:
```bash
bun run src/index.ts sync k2
```

## Troubleshooting

### "secret_key error" in logs

Your secret key is not set or invalid. Generate a new one:
```bash
openssl rand -hex 32
```

Update in `~/.config/searxng/settings.yml` and restart.

### Service won't start

Check if images pulled successfully:
```bash
podman pull docker.io/searxng/searxng:latest
podman pull docker.io/valkey/valkey:8-alpine
```

Check configuration files exist:
```bash
ls -la ~/.config/searxng/
```

### Can't access the web interface

Verify:
1. Service is running: `systemctl --user status searxng.service`
2. Port is accessible: `curl http://localhost:8080`
3. Reverse proxy is configured correctly
4. DNS points to k2

### "Redis connection refused" in logs

Valkey service not running:
```bash
systemctl --user status searxng-valkey.service
systemctl --user start searxng-valkey.service
```

Verify network connectivity:
```bash
podman exec searxng ping searxng-valkey
```

### Search results not cached

Check Valkey is running and accessible:
```bash
podman exec searxng-valkey valkey-cli ping
# Should respond: PONG
```

Check redis URL in settings.yml:
```yaml
redis:
  url: redis://searxng-valkey:6379/0
```

### Container logs

View container logs directly:
```bash
podman logs searxng
podman logs searxng-valkey
```

## Security Considerations

1. **Secret Key**: Must be randomly generated and kept secret
2. **Rate Limiting**: Enabled by default to prevent abuse
3. **Image Proxy**: Enabled by default for privacy
4. **HTTPS**: Use your reverse proxy for TLS termination
5. **Updates**: Keep SearXNG updated for security patches

## Performance Tuning

### Valkey Memory Limit

To limit Valkey memory usage, edit `searxng-valkey.container`:
```ini
Exec=valkey-server --save 30 1 --loglevel warning --maxmemory 256mb --maxmemory-policy allkeys-lru
```

### Cache Settings

Adjust cache behavior in `settings.yml`:
```yaml
search:
  formats:
    - html
    - json
  
outgoing:
  request_timeout: 3.0
  max_request_timeout: 10.0
```

## Features

- 🔒 **Privacy-Focused** - No tracking, no profiling
- 🔍 **Meta-Search** - Aggregates results from 70+ search engines
- 🎨 **Customizable** - Extensive configuration options
- ⚡ **Fast** - Cached results via Valkey/Redis
- 🌍 **Multilingual** - Support for many languages
- 📱 **Responsive** - Works on all devices
- 🔧 **Extensible** - Plugin system for custom engines

## References

- [SearXNG Official Site](https://docs.searxng.org/)
- [SearXNG GitHub](https://github.com/searxng/searxng)
- [Settings Documentation](https://docs.searxng.org/admin/settings/index.html)
- [Engines Documentation](https://docs.searxng.org/admin/engines/index.html)
- [Instance List](https://searx.space/) - See other public instances
- [Podman Quadlet Documentation](../../docs/quadlet.md)



