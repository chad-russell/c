# Arr Stack Quadlet Setup

This directory contains Podman Quadlet files for running the complete *arr media automation stack.

## Overview

The *arr stack automates downloading and organizing TV shows and movies. This setup includes:

- **Sonarr** - TV show management and automation
- **Radarr** - Movie management and automation
- **Prowlarr** - Indexer manager (connects to torrent/usenet indexers)
- **Jellyseerr** - Beautiful request management UI

## Architecture

```
Users → Jellyseerr → Sonarr/Radarr → Prowlarr → qBittorrent → Media Library → Jellyfin
```

## Files

- `arr.network` - Shared network for all *arr services
- `arr-sonarr-config.volume` - Sonarr configuration and database
- `arr-radarr-config.volume` - Radarr configuration and database
- `arr-prowlarr-config.volume` - Prowlarr configuration and database
- `arr-jellyseerr-config.volume` - Jellyseerr configuration
- `arr-sonarr.container` - Sonarr TV show manager
- `arr-radarr.container` - Radarr movie manager
- `arr-prowlarr.container` - Prowlarr indexer manager
- `arr-jellyseerr.container` - Jellyseerr request manager
- `arr-qbittorrent.container` - qBittorrent download client
- `arr-jellyfin.container` - Jellyfin media server

## Prerequisites

Your k1 machine must have:
1. ✅ qBittorrent running
2. ✅ Jellyfin running
3. ✅ NAS mounted at `/mnt/media` with this structure:
   ```
   /mnt/media/
   ├── Downloads/    # qBittorrent downloads here
   ├── Movies/       # Radarr organizes movies here
   └── TV/           # Sonarr organizes TV shows here
   ```

## Installation

### 1. Verify Path Consistency

**CRITICAL**: All containers must see the same paths! Verify your existing containers:

```bash
# Check qBittorrent paths
ssh k1 'podman inspect qbittorrent | grep -A 20 Mounts'
# Should show: /mnt/media → /media

# Check Jellyfin paths
ssh k1 'podman inspect jellyfin | grep -A 20 Mounts'
# Should show: /mnt/media → /media
```

All containers (qBittorrent, Sonarr, Radarr, Jellyfin) now use the same `/media` mount for consistency.

### 2. Enable User Service Persistence (If Not Already Done)

```bash
ssh k1 'loginctl enable-linger $USER'
```

### 3. Deploy with Your Tool

```bash
# Add arr to k1 in machines/machines.yaml
# Then sync:
bun run src/index.ts sync k1
```

### 4. Access the Services

After deployment:
- **Sonarr**: http://k1:8989
- **Radarr**: http://k1:7878
- **Prowlarr**: http://k1:9696
- **Jellyseerr**: http://k1:5055

## Configuration Steps

Follow these steps in order to set up the stack:

### Step 1: Configure Prowlarr (First!)

1. Open http://k1:9696
2. Complete initial setup
3. Add your indexers:
   - Settings → Indexers → Add Indexer
   - Add your favorite torrent sites (e.g., 1337x, RARBG alternatives, etc.)
4. Note: You'll connect Prowlarr to Sonarr/Radarr in Step 3

### Step 2: Configure Sonarr & Radarr

#### Sonarr (http://k1:8989)

1. **Add Root Folder**:
   - Settings → Media Management → Root Folders → Add
   - Path: `/media/TV`
   - This is where organized TV shows will be stored

2. **Add Download Client (qBittorrent)**:
   - Settings → Download Clients → Add → qBittorrent
   - Name: qBittorrent
   - Host: `k1` (or the host IP)
   - Port: `8080`
   - Category: `tv-sonarr` (create this in qBittorrent)
   - Directory: `/media/Downloads` (where qBittorrent saves files)

3. **Configure Quality Profiles**:
   - Settings → Profiles
   - Customize to your preferences (e.g., 1080p, 4K)

#### Radarr (http://k1:7878)

1. **Add Root Folder**:
   - Settings → Media Management → Root Folders → Add
   - Path: `/media/Movies`
   - This is where organized movies will be stored

2. **Add Download Client (qBittorrent)**:
   - Settings → Download Clients → Add → qBittorrent
   - Name: qBittorrent
   - Host: `k1` (or the host IP)
   - Port: `8080`
   - Category: `movies-radarr` (create this in qBittorrent)
   - Directory: `/media/Downloads`

3. **Configure Quality Profiles**:
   - Settings → Profiles
   - Customize to your preferences

### Step 3: Connect Prowlarr to Sonarr & Radarr

1. Go to Prowlarr → Settings → Apps → Add Application

2. **Add Sonarr**:
   - Select: Sonarr
   - Prowlarr Server: `http://prowlarr:9696`
   - Sonarr Server: `http://sonarr:8989`
   - API Key: Get from Sonarr → Settings → General → API Key
   - Test and Save

3. **Add Radarr**:
   - Select: Radarr
   - Prowlarr Server: `http://prowlarr:9696`
   - Radarr Server: `http://radarr:7878`
   - API Key: Get from Radarr → Settings → General → API Key
   - Test and Save

### Step 4: Configure Jellyseerr

1. Open http://k1:5055
2. **Initial Setup**:
   - Sign in with your Jellyfin account
   - Click "Use Your Jellyfin Account"
   - Enter: `http://k1:8096` (your Jellyfin URL)
   - Import your Jellyfin libraries

3. **Connect Sonarr**:
   - Settings → Services → Sonarr → Add Server
   - Server Name: Sonarr
   - Hostname/IP: `k1`
   - Port: `8989`
   - API Key: Get from Sonarr → Settings → General → API Key
   - Root Folder: Select `/media/TV`
   - Quality Profile: Select your preferred profile
   - Test and Save

4. **Connect Radarr**:
   - Settings → Services → Radarr → Add Server
   - Server Name: Radarr
   - Hostname/IP: `k1`
   - Port: `7878`
   - API Key: Get from Radarr → Settings → General → API Key
   - Root Folder: Select `/media/Movies`
   - Quality Profile: Select your preferred profile
   - Test and Save

### Step 5: Test the Stack

1. In Jellyseerr, search for a TV show or movie
2. Click "Request"
3. The request goes to Sonarr/Radarr
4. Sonarr/Radarr searches indexers via Prowlarr
5. Downloads are sent to qBittorrent
6. When complete, Sonarr/Radarr moves and renames files
7. Jellyfin automatically detects new media

## Managing Services

Check status:
```bash
systemctl --user status sonarr.service
systemctl --user status radarr.service
systemctl --user status prowlarr.service
systemctl --user status jellyseerr.service
```

View logs:
```bash
journalctl --user -u sonarr.service -f
journalctl --user -u radarr.service -f
journalctl --user -u prowlarr.service -f
journalctl --user -u jellyseerr.service -f
```

Stop services:
```bash
systemctl --user stop sonarr.service
systemctl --user stop radarr.service
systemctl --user stop prowlarr.service
systemctl --user stop jellyseerr.service
```

## Path Configuration Reference

**Critical for troubleshooting**: All services must use the same paths!

| Service | Container Path | Host Path | Purpose |
|---------|---------------|-----------|---------|
| qBittorrent | `/media` | `/mnt/media` | Full NAS access |
| qBittorrent Downloads | `/media/Downloads` | `/mnt/media/Downloads` | Download location |
| Sonarr | `/media` | `/mnt/media` | Full NAS access |
| Sonarr Root | `/media/TV` | `/mnt/media/TV` | TV library |
| Radarr | `/media` | `/mnt/media` | Full NAS access |
| Radarr Root | `/media/Movies` | `/mnt/media/Movies` | Movie library |
| Jellyfin | `/media` | `/mnt/media` | Full NAS access |

**All containers now use consistent `/media` paths - no remote path mapping needed!**

## Troubleshooting

### "No indexers available" in Sonarr/Radarr

- Configure Prowlarr first
- Add indexers to Prowlarr
- Connect Prowlarr to Sonarr/Radarr (Step 3)
- Wait a few minutes for sync

### "Unable to add download" error

Check download client configuration:
- qBittorrent must be accessible from Sonarr/Radarr
- Use `k1` or host IP as hostname
- Verify qBittorrent username/password if set
- Create categories in qBittorrent

### Files not moving after download

Path mismatch! All containers should see the same paths. Verify:
1. qBittorrent saves to `/media/Downloads`
2. Sonarr/Radarr see download dir as `/media/Downloads`
3. Sonarr/Radarr root folders are `/media/TV` and `/media/Movies`

Run this to check all containers can access the paths:
```bash
podman exec qbittorrent ls -la /media/Downloads
podman exec sonarr ls -la /media/Downloads
podman exec radarr ls -la /media/Downloads
```

### Jellyseerr can't connect to services

- Verify you used `k1` as hostname (not `localhost` or `127.0.0.1`)
- Check API keys are correct
- Ensure services are running

### Permission errors on NAS

The containers run as PUID=1000 and PGID=1000. Make sure this user has write access to:
- `/mnt/media/Downloads/`
- `/mnt/media/TV/`
- `/mnt/media/Movies/`

## Updating Services

To update to the latest versions:

```bash
# Update all at once
podman pull lscr.io/linuxserver/sonarr:latest
podman pull lscr.io/linuxserver/radarr:latest
podman pull lscr.io/linuxserver/prowlarr:latest
podman pull docker.io/fallenbagel/jellyseerr:latest

systemctl --user restart sonarr.service
systemctl --user restart radarr.service
systemctl --user restart prowlarr.service
systemctl --user restart jellyseerr.service
```

## Optional: Categories in qBittorrent

Create these categories in qBittorrent for better organization:
- `tv-sonarr` - TV shows from Sonarr
- `movies-radarr` - Movies from Radarr

This helps separate downloads by type.

## Data Persistence

All configuration is stored in named volumes:
- `arr-sonarr-config` - Sonarr database and settings
- `arr-radarr-config` - Radarr database and settings
- `arr-prowlarr-config` - Prowlarr indexers and settings
- `arr-jellyseerr-config` - Jellyseerr database and settings

Media files are stored on your NAS at `/mnt/media`.

View volumes:
```bash
podman volume ls | grep arr
```

## References

- [Sonarr Wiki](https://wiki.servarr.com/sonarr)
- [Radarr Wiki](https://wiki.servarr.com/radarr)
- [Prowlarr Wiki](https://wiki.servarr.com/prowlarr)
- [Jellyseerr Documentation](https://docs.jellyseerr.dev/)
- [TRaSH Guides](https://trash-guides.info/) - Quality profiles and custom formats
- [Podman Quadlet Documentation](../../docs/quadlet.md)



