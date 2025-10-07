# Fix for Sonarr Not Importing Episodes

## Problem Identified

Sonarr logs show this error repeatedly:
```
Import failed, path does not exist or is not accessible by Sonarr: /downloads/Abbott Elementary...
```

**Root Cause:** Path mismatch between containers
- qBittorrent was mounted with `/mnt/media/Downloads → /downloads`
- Sonarr is mounted with `/mnt/media → /media`
- When qBittorrent tells Sonarr "file is at `/downloads/file.mkv`", Sonarr can't find it
- Sonarr sees those files at `/media/Downloads/file.mkv`

## Solution Applied

Updated `qbittorrent.container` to use the same `/media` mount as all other containers for consistency.

## Steps to Deploy the Fix

### 1. Deploy Updated Configuration

```bash
# From your local machine
cd ~/Code/c
bun run src/index.ts sync k1
```

This will update the qBittorrent service configuration on k1.

### 2. Restart qBittorrent

After syncing, you need to restart qBittorrent for the new mount to take effect:

```bash
ssh crussell@k1 'systemctl --user restart qbittorrent.service'
```

### 3. Verify the Fix

Check that qBittorrent now sees the correct path:

```bash
# Should now show /media/Downloads
ssh crussell@k1 'podman exec qbittorrent ls -la /media/Downloads | head -10'
```

### 4. Update qBittorrent Download Path

**IMPORTANT:** You need to update qBittorrent's download directory setting:

1. Open qBittorrent Web UI: http://k1:8080
2. Go to **Settings** (gear icon) → **Downloads**
3. Change **Default Save Path** from `/downloads` to `/media/Downloads`
4. Click **Save**

### 5. Verify Sonarr Configuration

Open Sonarr at http://k1:8989 and verify:

1. **Settings → Download Clients**
   - Click on your qBittorrent client
   - **Host:** should be `qbittorrent` (not `k1` or an IP address)
   - **Port:** `8080`
   - Click **Test** to verify connection
   - **Save**

2. **Settings → Download Clients → Advanced Settings (Show)**
   - Scroll down to **Completed Download Handling**
   - Make sure ✅ **Enable** is checked
   - **Remove:** Choose your preference (whether to remove completed torrents)

### 6. Test the Import

Since you already have Abbott Elementary files in the downloads folder, Sonarr should automatically try to import them. Watch the logs:

```bash
ssh crussell@k1 'journalctl --user -u sonarr.service -f'
```

You should see successful import messages instead of the `/downloads` path errors.

### 7. Manual Import (If Needed)

If automatic import doesn't work immediately:

1. Open Sonarr: http://k1:8989
2. Go to **Activity → Queue** or **Wanted → Manual Import**
3. Browse to `/media/Downloads`
4. Select the Abbott Elementary files
5. Click **Import**

## What Changed

### Files Modified

1. **`services/arr/qbittorrent.container`**
   - Changed from: `Volume=/mnt/media/Downloads:/downloads`
   - Changed to: `Volume=/mnt/media:/media`

2. **`services/arr/README.md`**
   - Updated path documentation to reflect consistent `/media` paths

3. **`services/arr/GETTING_STARTED.md`**
   - Updated path references and troubleshooting guide

## Expected Result

After completing these steps:

1. ✅ All containers (qBittorrent, Sonarr, Radarr, Jellyfin) see media at `/media`
2. ✅ No more path mismatch errors in Sonarr logs
3. ✅ Abbott Elementary episodes get imported to `/mnt/media/TV/Abbott Elementary/`
4. ✅ Jellyfin automatically detects new episodes
5. ✅ Future downloads work automatically

## Verification Commands

```bash
# Check all containers can access the same paths
ssh crussell@k1 'podman exec qbittorrent ls -la /media/Downloads | head -5'
ssh crussell@k1 'podman exec sonarr ls -la /media/Downloads | head -5'
ssh crussell@k1 'podman exec jellyfin ls -la /media/TV | head -5'

# Watch for successful imports
ssh crussell@k1 'journalctl --user -u sonarr.service -f | grep -i import'

# Check if Abbott Elementary folder was created
ssh crussell@k1 'ls -la /mnt/media/TV/ | grep -i abbott'
```

## Need Help?

If you still see issues after following these steps, check:
1. qBittorrent download path is set to `/media/Downloads` in qBittorrent settings
2. Sonarr download client hostname is `qbittorrent` (not `k1`)
3. All services are running: `ssh crussell@k1 'podman ps'`
4. Check Sonarr logs for new error messages

