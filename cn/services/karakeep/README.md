# KaraKeep HomeDash Quadlet Setup

This directory contains Podman Quadlet files for running KaraKeep HomeDash, a compact dashboard for browsing your [KaraKeep](https://github.com/karakeep-app/karakeep) bookmarks.

## Overview

KaraKeep HomeDash provides a clean, single-page view of all your bookmarks organized by lists. It's designed to be a simple, uncluttered dashboard that complements the full KaraKeep app.

## Features

- 📚 **Masonry Layout** - Pinterest-style columns for efficient space use
- 🔍 **Real-time Search** - Instantly filter bookmarks as you type
- 🖱️ **Drag & Drop** - Reorder lists to your preference
- 📱 **Responsive** - Works beautifully on desktop, tablet, and mobile
- 🚀 **Fast** - SQLite WASM runs entirely in your browser
- 🔒 **Privacy-First** - Your data never leaves your device

## Architecture

KaraKeep HomeDash is a companion app that reads your KaraKeep database in read-only mode to display a dashboard view.

## Files

- `karakeep-homedash-config.volume` - Config persistence (dashboard preferences, column order)
- `karakeep-homedash.container` - Main dashboard application

## Prerequisites

**IMPORTANT**: KaraKeep must be installed and running before deploying HomeDash!

HomeDash requires:
1. A running KaraKeep instance (see `services/karakeep/`)
2. Access to the KaraKeep database volume (`karakeep-app-data`)
3. Both services must be on the same network (`karakeep.network`)

## Installation

### 1. Ensure KaraKeep is Running

Make sure KaraKeep is already deployed and working:

```bash
systemctl --user status karakeep.service
```

### 2. Configure HomeDash Settings

Edit `karakeep-homedash.container` and set:

**KARAKEEP_URL**: Set to your KaraKeep instance URL (e.g., `http://k4:3322` or `https://karakeep.yourdomain.com`)

This URL is used for the "Go to KaraKeep" link in the dashboard interface.

### 3. Deploy with Your Tool

If you're using the homelab deployment tool:

```bash
# Add karakeep-homedash to your machine in machines/machines.yaml
# Then sync:
bun run src/index.ts sync k4
```

Or manually for rootless deployment:

```bash
mkdir -p ~/.config/containers/systemd/
cp services/karakeep-homedash/*.{container,volume} ~/.config/containers/systemd/
systemctl --user daemon-reload
systemctl --user start karakeep-homedash.service
systemctl --user enable karakeep-homedash.service
```

## Accessing KaraKeep HomeDash

Once running, access the dashboard at: **http://k4:8595** (or http://localhost:8595)

The dashboard will automatically load your KaraKeep bookmarks organized by lists.

## Managing Services

Check status:
```bash
systemctl --user status karakeep-homedash.service
```

View logs:
```bash
journalctl --user -u karakeep-homedash.service -f
```

Stop service:
```bash
systemctl --user stop karakeep-homedash.service
```

## Configuration Options

Edit `karakeep-homedash.container` to customize:

### Basic Settings
- **Port**: Change `PublishPort=8595:8595` if you need a different host port
- **KARAKEEP_URL**: URL to your KaraKeep instance (for navigation links)

### Dashboard Preferences

Dashboard preferences (like column order from drag-and-drop) are automatically saved to the `karakeep-homedash-config` volume via the web interface.

## Data Access

HomeDash mounts the KaraKeep database volume in **read-only mode**:
- **Volume**: `karakeep-app-data` (shared with KaraKeep)
- **Mount Point**: `/mnt/karakeep-data` in HomeDash container
- **Database Path**: A symbolic link is created from `/mnt/karakeep-data/db.db` to `/app/db.db` at startup
- **Mode**: Read-only (`:ro`) - HomeDash never modifies your data

All bookmark management should be done through the main KaraKeep app.

## How It Works

1. **Database Access**: HomeDash reads the KaraKeep SQLite database directly using SQLite WASM in your browser
2. **Client-Side Processing**: All database queries run in your browser - the server just serves static files
3. **Privacy-First**: Your bookmark data never leaves your device
4. **Auto-Updates**: Refresh the page to see new bookmarks added via KaraKeep

## Updating HomeDash

To update to the latest version:

```bash
podman pull ghcr.io/codejawn/karakeep-homedash:latest
systemctl --user restart karakeep-homedash.service
```

## Troubleshooting

### Service won't start

Check if the image pulled successfully:
```bash
podman pull ghcr.io/codejawn/karakeep-homedash:latest
```

Verify KaraKeep is running:
```bash
systemctl --user status karakeep.service
```

### "Could not find db.db"

Make sure:
1. KaraKeep is running and has created its database
2. The `karakeep-app-data` volume exists and contains data
3. Check the volume mount: `podman inspect karakeep-homedash | grep -A 10 Mounts`

### Bookmarks not showing

1. Verify KaraKeep has bookmarks by logging into the main app
2. Check the database file exists:
   ```bash
   podman volume inspect karakeep-app-data
   # Note the Mountpoint path, then check for db.db
   ```
3. Check browser console for errors (F12 in most browsers)
4. Refresh the page to reload the database

### Drag and drop not saving

Verify the config volume is writable:
```bash
podman volume inspect karakeep-homedash-config
```

Check container logs for permission errors:
```bash
journalctl --user -u karakeep-homedash.service -f
```

### Container logs

View container logs directly:
```bash
podman logs karakeep-homedash
journalctl --user -u karakeep-homedash.service -f
```

## Network Configuration

HomeDash runs on the same network as KaraKeep (`karakeep.network`). This allows:
- Shared network namespace for container communication
- Access to the same volumes
- Simplified deployment on the same host

If you need to access HomeDash from a different machine, consider using a reverse proxy or adjusting the `PublishPort` configuration.

## References

- [KaraKeep HomeDash GitHub](https://github.com/CodeJawn/karakeep-homedash)
- [KaraKeep Main App](https://github.com/karakeep-app/karakeep)
- [KaraKeep Documentation](https://docs.karakeep.app/)
- [SQLite WASM](https://sqlite.org/wasm/doc/trunk/index.md)
- [Podman Quadlet Documentation](../../docs/quadlet.md)



