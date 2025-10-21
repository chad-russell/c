# Quick Deploy Guide

## ✅ Service Deployed and Stable!

The service has been fixed and is now running:

### What Was Fixed

1. **Path Mismatch**: qBittorrent now uses the same `/media` mount as Sonarr/Radarr/Jellyfin
2. **Service Detection**: All files prefixed with `arr-` for proper grouping
3. **Sync Stability**: Service detection is now stable and idempotent

### All Services Running

```bash
ssh crussell@k1 'podman ps'
```

Should show: sonarr, radarr, prowlarr, jellyseerr, qbittorrent, jellyfin

If any are missing, start them:
```bash
ssh crussell@k1 'systemctl --user start arr-radarr.service arr-prowlarr.service arr-jellyseerr.service arr-qbittorrent.service arr-jellyfin.service'
```

### After Deployment

You **must** update qBittorrent's download path:

1. Open qBittorrent Web UI: **http://k1:8080**
2. Go to **Settings** → **Downloads**
3. Change **Default Save Path** from `/downloads` to `/media/Downloads`
4. Click **Save**

### Verify It's Working

Watch Sonarr logs to see successful imports:
```bash
ssh crussell@k1 'journalctl --user -u sonarr.service -f | grep -i import'
```

You should see import success messages instead of path errors!

### Check Abbott Elementary

After a few minutes, check if episodes were imported:
```bash
ssh crussell@k1 'ls -la /mnt/media/TV/ | grep -i abbott'
```

If you see an "Abbott Elementary" folder, it worked! The episodes should now appear in Jellyfin.

---

## Full Details

- **Path fix details**: See `FIX_INSTRUCTIONS.md`
- **Service rename details**: See `../FIXES_SUMMARY.md`
- **Configuration guide**: See `GETTING_STARTED.md`

