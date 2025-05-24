# 🏠 Home Compute Cluster

A 4-node highly available NixOS cluster with SeaweedFS distributed storage and Keepalived failover.

## 🚀 Quick Start

### Deploy to all nodes
```bash
nix run .#deploy
```

### Deploy to specific nodes
```bash
nix run .#deploy c1 c2    # Deploy to c1 and c2
nix run .#deploy c1       # Deploy only to c1
```

### Non-interactive deployment
```bash
nix run .#deploy -- --all --yes
```

### Check prerequisites only
```bash
nix run .#deploy -- --check-only
```

### See all options
```bash
nix run .#deploy -- --help
```

## 🛠️ Development

### Enter development shell
```bash
nix develop
```

### Alternative: Use the legacy bash script
```bash
./deploy.sh
```

## 📖 Setup Guide

See [SETUP.md](./SETUP.md) for complete setup instructions.

## 🏗️ Architecture

### Cluster Nodes
- **c1** (192.168.68.71): Master, Volume, Filer, Keepalived (Priority 120)
- **c2** (192.168.68.72): Master, Volume, Filer, Keepalived (Priority 110)  
- **c3** (192.168.68.73): Master, Volume, Keepalived (Priority 100)
- **c4** (192.168.68.74): Volume, Keepalived (Priority 90)

### Virtual IP
- **192.168.68.70**: Managed by Keepalived for high availability

### Services
- **SeaweedFS Masters**: Port 9333 on c1, c2, c3
- **SeaweedFS Volumes**: Port 8080 on all nodes  
- **SeaweedFS Filers**: Port 8888 on c1, c2

### Storage
- **System**: Btrfs on /dev/nvme0n1 with subvolumes
- **Data**: xfs on /dev/nvme1n1 for SeaweedFS volumes

## 🔐 Security

- Secrets managed with sops-nix and age encryption
- SSH key deployment via nixos-anywhere extra-files
- No passwords - key-based authentication only

## 🎯 Features

### Deployment Tool
- ✅ Interactive deployment with confirmations
- ✅ Beautiful terminal output with tables and progress
- ✅ Comprehensive prerequisite checking
- ✅ Robust error handling and logging
- ✅ Parallel deployment support
- ✅ Colored output and progress indicators
- ✅ Verbose debugging mode

### Infrastructure
- ✅ High availability with automatic failover
- ✅ Distributed storage with SeaweedFS
- ✅ Declarative configuration with NixOS
- ✅ Secrets management with sops-nix
- ✅ Automated deployment with nixos-anywhere

## 📁 Project Structure

```
.
├── flake.nix                 # Main flake configuration
├── .sops.yaml               # SOPS encryption config
├── deploy.sh                # Legacy bash deployment script
├── scripts/
│   └── deploy.py            # Python deployment tool
├── modules/
│   └── common.nix           # Shared configuration
├── hosts/
│   ├── c1/
│   │   ├── configuration.nix
│   │   └── disko.nix
│   ├── c2/...
│   ├── c3/...
│   └── c4/...
├── secrets/
│   └── secrets.yaml         # Encrypted secrets
├── SETUP.md                 # Detailed setup guide
└── README.md                # This file
```

## 🔧 Troubleshooting

### Check deployment status
```bash
nix run .#deploy -- --check-only
```

### Verbose logging
```bash
nix run .#deploy -- --verbose
```

### Manual verification
```bash
# SSH to nodes
ssh crussell@192.168.68.71

# Check services
systemctl status seaweedfs-master
systemctl status keepalived

# Check SeaweedFS cluster
curl http://192.168.68.71:9333/cluster/status
```

---

Made with ❤️ and NixOS for reliable home infrastructure. 