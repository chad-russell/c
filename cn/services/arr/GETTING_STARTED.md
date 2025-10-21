# Getting Started with Your Arr Stack

This guide walks you through configuring your complete media automation stack from scratch.

## What You Have

- **Jellyfin** (http://k1:8096) - Media server
- **qBittorrent** (http://k1:8080) - Download client
- **Sonarr** (http://k1:8989) - TV show automation
- **Radarr** (http://k1:7878) - Movie automation
- **Prowlarr** (http://k1:9696) - Indexer manager
- **Jellyseerr** (http://k1:5055) - Request management

## Prerequisites

Before starting, ensure:
- ✅ All services are running: `ssh k1 'podman ps'`
- ✅ NAS is mounted at `/mnt/media` with these folders:
  - `/mnt/media/Downloads/` (qBittorrent downloads)
  - `/mnt/media/TV/` (TV shows library)
  - `/mnt/media/Movies/` (Movies library)

## Configuration Order

**IMPORTANT:** Configure in this exact order! Services depend on each other.

1. Prowlarr (add indexers)
2. Sonarr (add download client and root folder)
3. Radarr (add download client and root folder)
4. Prowlarr (connect to Sonarr and Radarr)
5. Jellyseerr (connect to everything)

---

## Step 1: Configure Prowlarr

**Open:** http://k1:9696

### Initial Setup
1. Complete the welcome wizard
2. Set authentication (recommended):
   - Settings → General → Authentication: `Forms (Login Page)`
   - Create username and password

### Add Indexers
1. Go to **Indexers → Add Indexer**
2. Search for your preferred indexers (examples):
   - **Public:** 1337x, EZTV, YTS, The Pirate Bay
   - **Private:** Add your private tracker credentials
3. For each indexer:
   - Configure any required settings (URLs, API keys, etc.)
   - Select categories (TV, Movies, etc.)
   - Test → Save
4. Repeat for all your indexers

**✓ Checkpoint:** You should now have multiple indexers listed in Prowlarr

---

## Step 2: Configure Sonarr (TV Shows)

**Open:** http://k1:8989

### Initial Setup
1. Complete the welcome wizard (if shown)
2. Set authentication (optional but recommended):
   - Settings → General → Authentication: `Forms (Login Page)`

### Add Root Folder
1. Go to **Settings → Media Management**
2. Click **Root Folders** tab
3. Click **Add Root Folder**
4. Enter path: `/media/TV`
5. Click the checkmark to save

### Add Download Client (qBittorrent)
1. Go to **Settings → Download Clients**
2. Click **+** to add download client
3. Select **qBittorrent**
4. Configure:
   ```
   Name: qBittorrent
   Host: qbittorrent
   Port: 8080
   Username: [your qBittorrent username, if set]
   Password: [your qBittorrent password, if set]
   Category: tv-sonarr (optional but recommended)
   ```
5. Click **Test** to verify connection
6. Click **Save**

**Important:** If qBittorrent requires authentication, you need to set/find your WebUI credentials in qBittorrent first.

### Optional: Configure Quality Profiles
1. Go to **Settings → Profiles**
2. Customize quality profiles to your preferences:
   - **HD-1080p** - Good for most content
   - **Ultra-HD** - 4K content
   - **SD** - Lower quality/smaller files

### Get API Key (Save This!)
1. Go to **Settings → General**
2. Scroll down to **Security** section
3. Copy the **API Key** - you'll need this for Prowlarr and Jellyseerr
4. Save it somewhere safe!

**✓ Checkpoint:** 
- Root folder `/media/TV` added
- qBittorrent connected successfully
- API key saved

---

## Step 3: Configure Radarr (Movies)

**Open:** http://k1:7878

### Initial Setup
1. Complete the welcome wizard (if shown)
2. Set authentication (optional but recommended):
   - Settings → General → Authentication: `Forms (Login Page)`

### Add Root Folder
1. Go to **Settings → Media Management**
2. Click **Root Folders** tab
3. Click **Add Root Folder**
4. Enter path: `/media/Movies`
5. Click the checkmark to save

### Add Download Client (qBittorrent)
1. Go to **Settings → Download Clients**
2. Click **+** to add download client
3. Select **qBittorrent**
4. Configure:
   ```
   Name: qBittorrent
   Host: qbittorrent
   Port: 8080
   Username: [your qBittorrent username, if set]
   Password: [your qBittorrent password, if set]
   Category: movies-radarr (optional but recommended)
   ```
5. Click **Test** to verify connection
6. Click **Save**

### Optional: Configure Quality Profiles
1. Go to **Settings → Profiles**
2. Customize quality profiles to your preferences
3. Consider using **HD-1080p** or **Ultra-HD** for movies

### Get API Key (Save This!)
1. Go to **Settings → General**
2. Scroll down to **Security** section
3. Copy the **API Key** - you'll need this for Prowlarr and Jellyseerr
4. Save it somewhere safe!

**✓ Checkpoint:**
- Root folder `/media/Movies` added
- qBittorrent connected successfully
- API key saved

---

## Step 4: Connect Prowlarr to Sonarr & Radarr

**Back to Prowlarr:** http://k1:9696

This is where the magic happens! Prowlarr will sync all your indexers to Sonarr and Radarr automatically.

### Add Sonarr
1. Go to **Settings → Apps**
2. Click **+** to add application
3. Select **Sonarr**
4. Configure:
   ```
   Sync Level: Add and Remove Only (or Full Sync)
   
   Prowlarr Server: http://prowlarr:9696
   Sonarr Server: http://sonarr:8989
   
   API Key: [paste your Sonarr API key]
   
   Sync Categories: 
     - TV/WEB-DL
     - TV/HD
     - TV/UHD
     - (select categories you want)
   
   Tags: (leave empty)
   ```
5. Click **Test** - should show green checkmark
6. Click **Save**

### Add Radarr
1. Still in **Settings → Apps**
2. Click **+** to add another application
3. Select **Radarr**
4. Configure:
   ```
   Sync Level: Add and Remove Only (or Full Sync)
   
   Prowlarr Server: http://prowlarr:9696
   Radarr Server: http://radarr:7878
   
   API Key: [paste your Radarr API key]
   
   Sync Categories:
     - Movies/WEB-DL
     - Movies/HD
     - Movies/UHD
     - (select categories you want)
   
   Tags: (leave empty)
   ```
5. Click **Test** - should show green checkmark
6. Click **Save**

### Verify Sync
1. **In Sonarr:** Go to Settings → Indexers
   - You should see all your Prowlarr indexers!
2. **In Radarr:** Go to Settings → Indexers
   - You should see all your Prowlarr indexers!

**✓ Checkpoint:** Both Sonarr and Radarr now have access to all your indexers

---

## Step 5: Configure Jellyseerr (Request Management)

**Open:** http://k1:5055

Jellyseerr provides a beautiful interface for requesting movies and TV shows.

### Initial Setup
1. Click **Use Your Jellyfin Account**
2. Enter Jellyfin URL: `http://jellyfin:8096`
3. Sign in with your Jellyfin credentials
4. Click **Sync Libraries** to import your existing media
5. Complete the setup wizard

### Connect Sonarr
1. Go to **Settings → Services**
2. Click **Sonarr** tab
3. Click **Add Sonarr Server**
4. Configure:
   ```
   Default Server: ✅ (check this)
   4K Server: ☐ (unless you have a separate 4K instance)
   
   Server Name: Sonarr
   Hostname or IP Address: sonarr
   Port: 8989
   API Key: [paste your Sonarr API key]
   URL Base: (leave empty)
   Use SSL: ☐
   
   Quality Profile: [Select your preferred profile, e.g., "HD-1080p"]
   Root Folder: /media/TV
   Language Profile: [Usually "English"]
   
   Tags: (leave empty)
   
   Anime Quality Profile: (optional)
   Anime Root Folder: (optional)
   Anime Language Profile: (optional)
   Anime Tags: (optional)
   
   Season Folders: ✅
   Enable Scan: ✅
   Enable Automatic Search: ✅
   ```
5. Click **Test** - should succeed
6. Click **Save Changes**

### Connect Radarr
1. Still in **Settings → Services**
2. Click **Radarr** tab
3. Click **Add Radarr Server**
4. Configure:
   ```
   Default Server: ✅ (check this)
   4K Server: ☐ (unless you have a separate 4K instance)
   
   Server Name: Radarr
   Hostname or IP Address: radarr
   Port: 7878
   API Key: [paste your Radarr API key]
   URL Base: (leave empty)
   Use SSL: ☐
   
   Quality Profile: [Select your preferred profile, e.g., "HD-1080p"]
   Root Folder: /media/Movies
   
   Tags: (leave empty)
   
   Minimum Availability: Released (or Announced for early tracking)
   
   Enable Scan: ✅
   Enable Automatic Search: ✅
   ```
5. Click **Test** - should succeed
6. Click **Save Changes**

### Optional: Configure Permissions
1. Go to **Settings → Users**
2. Set request limits and permissions for each user
3. Configure auto-approval settings if desired

**✓ Checkpoint:** Jellyseerr is connected to Jellyfin, Sonarr, and Radarr

---

## Step 6: Test the Complete Flow! 🎉

Time to see it all work together!

### Request Content via Jellyseerr
1. Open **Jellyseerr** (http://k1:5055)
2. Search for a TV show or movie
3. Click on the result
4. Click **Request** button
5. Confirm the request

### Watch the Automation
1. **Jellyseerr** sends request to Sonarr/Radarr
2. **Sonarr/Radarr** searches indexers via Prowlarr
3. **Prowlarr** queries all your configured indexers
4. **Sonarr/Radarr** picks the best result
5. **qBittorrent** starts downloading
6. **Sonarr/Radarr** monitors progress
7. When complete, **Sonarr/Radarr** moves and renames files
8. Files appear in `/mnt/media/TV/` or `/mnt/media/Movies/`
9. **Jellyfin** automatically detects new media
10. **Watch in Jellyfin!** 🍿

### Monitor Progress
- **qBittorrent:** Check download progress (http://k1:8080)
- **Sonarr/Radarr:** Check queue and activity (Activity tab)
- **Jellyseerr:** Check request status (Requests page)

---

## Common Issues & Solutions

### "No indexers available" in Sonarr/Radarr

**Problem:** Sonarr/Radarr can't search for content

**Solution:**
1. Check Prowlarr is connected: Settings → Apps in Prowlarr
2. Verify indexers are enabled in Prowlarr
3. Force sync: In Prowlarr, edit the app and click "Sync App Indexers"
4. Check Sonarr/Radarr → Settings → Indexers - should see your indexers

### "Unable to add to download queue" error

**Problem:** Sonarr/Radarr can't send downloads to qBittorrent

**Solution:**
1. Verify qBittorrent is running: `podman ps | grep qbittorrent`
2. Check qBittorrent credentials in Sonarr/Radarr download client settings
3. Test the connection in Settings → Download Clients
4. Ensure the hostname is `qbittorrent` (not `localhost` or IP)

### Files not moving after download

**Problem:** Downloads complete but stay in Downloads folder

**Solution:**
1. Check paths match across all containers:
   - qBittorrent saves to: `/media/Downloads` (same as other containers)
   - Sonarr/Radarr see downloads at: `/media/Downloads`
   - Sonarr moves to: `/media/TV`
   - Radarr moves to: `/media/Movies`
2. Verify permissions on NAS folders
3. Check Sonarr/Radarr logs for errors: System → Logs

### Jellyseerr can't connect to services

**Problem:** Test connection fails in Jellyseerr

**Solution:**
1. Use container names, not IPs:
   - Jellyfin: `http://jellyfin:8096`
   - Sonarr: `sonarr` (hostname only)
   - Radarr: `radarr` (hostname only)
2. Verify API keys are correct
3. Ensure services are running on arr network

### Categories not working in qBittorrent

**Problem:** Want to separate TV and Movie downloads

**Solution:**
1. Open qBittorrent (http://k1:8080)
2. Right-click in category sidebar → Add category
3. Create categories: `tv-sonarr` and `movies-radarr`
4. Use these in Sonarr/Radarr download client settings

---

## Optional Enhancements

### Quality Profiles with Custom Formats (TRaSH Guides)

For advanced quality management:
1. Visit [TRaSH Guides](https://trash-guides.info/)
2. Follow their custom format guides for Sonarr/Radarr
3. Import quality profiles optimized for different use cases

### qBittorrent Categories

Create these for better organization:
- `tv-sonarr` - TV shows
- `movies-radarr` - Movies
- `manual` - Manual downloads

### Backup Your Config

**Important locations to backup:**
```bash
# On k1:
~/.config/jellyfin/config/       # Jellyfin database and settings
~/.config/qbittorrent/           # qBittorrent settings
podman volume export arr-sonarr-config > arr-sonarr-backup.tar
podman volume export arr-radarr-config > arr-radarr-backup.tar
podman volume export arr-prowlarr-config > arr-prowlarr-backup.tar
podman volume export arr-jellyseerr-config > arr-jellyseerr-backup.tar
```

See [VOLUMES.md](../../docs/VOLUMES.md) for detailed backup instructions.

---

## Quick Reference

### Service URLs
| Service | URL | Purpose |
|---------|-----|---------|
| Jellyfin | http://k1:8096 | Watch media |
| qBittorrent | http://k1:8080 | Manage downloads |
| Sonarr | http://k1:8989 | Manage TV shows |
| Radarr | http://k1:7878 | Manage movies |
| Prowlarr | http://k1:9696 | Manage indexers |
| Jellyseerr | http://k1:5055 | Request content |

### Container Names (for inter-service communication)
- `jellyfin`
- `qbittorrent`
- `sonarr`
- `radarr`
- `prowlarr`
- `jellyseerr`

### Important Paths (Inside Containers)
| Service | Internal Path | Host Path | Purpose |
|---------|--------------|-----------|---------|
| All | `/media` | `/mnt/media` | Full NAS access |
| qBittorrent | `/media/Downloads` | `/mnt/media/Downloads` | Download location |
| Sonarr | `/media/TV` | `/mnt/media/TV` | TV library |
| Radarr | `/media/Movies` | `/mnt/media/Movies` | Movie library |
| Jellyfin | `/media` | `/mnt/media` | Media library |

### Useful Commands

```bash
# Check all services are running
ssh k1 'podman ps'

# Check service status
ssh k1 'systemctl --user status sonarr.service'

# View logs
ssh k1 'journalctl --user -u sonarr.service -f'

# Restart a service
ssh k1 'systemctl --user restart sonarr.service'

# Check your deployment tool status
bun run src/index.ts status k1
```

---

## Need Help?

- **Sonarr Wiki:** https://wiki.servarr.com/sonarr
- **Radarr Wiki:** https://wiki.servarr.com/radarr
- **Prowlarr Wiki:** https://wiki.servarr.com/prowlarr
- **Jellyseerr Docs:** https://docs.jellyseerr.dev/
- **TRaSH Guides:** https://trash-guides.info/ (Quality profiles and best practices)

---

**Last Updated:** October 2025

**Your Stack Version:**
- Sonarr: latest (LinuxServer.io)
- Radarr: latest (LinuxServer.io)
- Prowlarr: latest (LinuxServer.io)
- Jellyseerr: latest
- Jellyfin: latest
- qBittorrent: latest (LinuxServer.io)

