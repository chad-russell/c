# K3 Ready to Deploy ✅

## Summary

All configuration files are ready for migrating k3 from Fedora to NixOS.

### What's Been Configured

**Services to Migrate:**
- ✅ n8n (workflow automation) - port 5678
- ✅ PinePods (podcast manager with PostgreSQL + Valkey) - port 8040
- ✅ SearXNG (search engine with Valkey cache) - port 8080

**System Configuration:**
- ✅ Hostname: k3
- ✅ Static IP: 192.168.20.63/24
- ✅ Gateway: 192.168.20.1
- ✅ DNS: 192.168.10.1, 8.8.8.8
- ✅ SSH access configured (root + crussell user)
- ✅ Your SSH key authorized
- ✅ Passwordless sudo enabled
- ✅ Disk layout: NVMe for OS, HDD (1.8T) for /srv

**Backup & Restore:**
- ✅ Backup script created
- ✅ Restore script created
- ✅ Migration workflow documented

---

## 🚀 Deployment Steps (Quick Version)

Follow these steps **in order**:

### 1. Backup

```bash
scp backup-k3-volumes.sh crussell@192.168.20.63:~/
ssh crussell@192.168.20.63 './backup-k3-volumes.sh'
```

### 2. Copy Backup to Local Machine

```bash
rsync -avz --progress crussell@192.168.20.63:/tmp/k3-migration-backup/ ./k3-backup/
```

### 3. Deploy NixOS

```bash
cd /home/crussell/Code/c/cn/nix
nixos-anywhere --flake .#k3 root@192.168.20.63
```

Wait ~10-15 minutes, then wait 2-3 more minutes for k3 to reboot.

### 4. Copy Backup Back to k3

```bash
rsync -avz --progress ./k3-backup/ crussell@192.168.20.63:/srv/k3-migration-backup/
```

### 5. Restore Data

```bash
scp restore-k3-volumes.sh crussell@192.168.20.63:~/
ssh crussell@192.168.20.63 './restore-k3-volumes.sh TIMESTAMP'
```

### 6. Verify

Test these URLs:
- http://192.168.20.63:5678 (n8n)
- http://192.168.20.63:8040 (PinePods)
- http://192.168.20.63:8080 (SearXNG)

---

## 📚 Detailed Documentation

- **BACKUP-AND-DEPLOY.md** - Complete step-by-step workflow with troubleshooting
- **K3-MIGRATION-STEPS.md** - Detailed migration guide
- **README.md** - Repository structure and overview

---

## ⚠️ Important Notes

1. **SSH Access**: You can SSH in immediately after nixos-anywhere completes:
   - `ssh crussell@192.168.20.63` (your regular user)
   - `ssh root@192.168.20.63` (emergency access)

2. **Data Safety**: 
   - Backup goes to `/tmp` on k3 first
   - Then copied to your local machine (survives the wipe)
   - Then copied back to `/srv` on new NixOS system

3. **Disk Configuration**:
   - `/dev/nvme0n1` = OS (NixOS) 
   - `/dev/sda` = `/srv` (container data)
   - Both drives will be wiped and reformatted

4. **Network**: Static IP configuration ensures k3 comes up at the same address

5. **Services**: All services start automatically after restore

---

## 🎯 Ready to Proceed?

**Read:** `BACKUP-AND-DEPLOY.md` for the complete workflow

**Then run:** The 6-step deployment above

**Questions?** Check the troubleshooting sections in the documentation

---

## File Structure Created

```
cn/nix/
├── flake.nix (single flake for all machines)
├── flake.lock
├── README.md
├── BACKUP-AND-DEPLOY.md ← START HERE
├── K3-MIGRATION-STEPS.md
├── K3-READY-TO-DEPLOY.md ← YOU ARE HERE
├── backup-k3-volumes.sh
├── restore-k3-volumes.sh
├── common/
│   ├── base-configuration.nix
│   ├── hardware-configuration.nix
│   ├── hardware-watchdog.nix
│   └── network-optimizations.nix
├── services/
│   ├── n8n.nix
│   ├── pinepods.nix
│   ├── searxng.nix
│   ├── karakeep.nix (k2)
│   ├── memos.nix (k2)
│   ├── ntfy.nix (k2)
│   └── papra.nix (k2)
├── k2/
│   ├── configuration.nix
│   └── disk-config.nix
└── k3/
    ├── configuration.nix
    └── disk-config.nix
```

Good luck! 🍀

