# 🚀 Home Cluster Setup Guide

This guide walks you through setting up your 4-node NixOS home cluster with SeaweedFS and high availability.

## 📋 Prerequisites

- 4 identical machines with:
  - 2 NVMe drives each (system + data)
  - Network connectivity on 192.168.68.x subnet
  - Ability to boot from USB/network for initial installation

## 🔐 Step 1: Set up SOPS and Age Keys

### Generate Age Key
```bash
# Create sops directory
mkdir -p ~/.config/sops/age

# Generate age key
age-keygen -o ~/.config/sops/age/keys.txt

# Note down the public key from the output
cat ~/.config/sops/age/keys.txt
```

### Configure SOPS
Create `~/.config/sops/age/keys.txt` with your private key, then set up the SOPS config:

```bash
# Create .sops.yaml in the project root
cat > .sops.yaml << EOF
keys:
  - &admin_key age1your_public_key_here
creation_rules:
  - path_regex: secrets/.*\.yaml$
    key_groups:
    - age:
      - *admin_key
EOF
```

## 🔑 Step 2: Set up SSH Keys and Secrets

### Add your SSH public key to secrets
```bash
# Edit the secrets file
editor secrets/secrets.yaml

# Add your actual SSH public key:
ssh_keys:
  crussell: |
    ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... your-actual-public-key-here
```

### Encrypt the secrets
```bash
# Encrypt the secrets file
sops -e -i secrets/secrets.yaml

# Verify it's encrypted
head secrets/secrets.yaml
# Should show sops metadata
```

## 🖥️ Step 3: Prepare Target Machines

Each target machine needs:

1. **Boot into a Linux live environment** (NixOS ISO, Ubuntu live, etc.)
2. **Enable SSH access for root**:
   ```bash
   # On each target machine:
   sudo passwd root  # Set root password
   sudo systemctl start sshd
   ip addr show      # Note the IP address
   ```

3. **Copy your SSH key to root** (for initial access):
   ```bash
   # From your deployment machine:
   ssh-copy-id root@192.168.68.71  # For c1
   ssh-copy-id root@192.168.68.72  # For c2
   ssh-copy-id root@192.168.68.73  # For c3
   ssh-copy-id root@192.168.68.74  # For c4
   ```

## 🚢 Step 4: Deploy the Cluster

### Install required tools
```bash
# Enter the development shell with all tools
nix develop

# Or install globally:
nix profile install nixpkgs#nixos-anywhere nixpkgs#sops nixpkgs#age
```

### Deploy to all nodes
```bash
# Deploy to all nodes at once
./deploy.sh

# Or deploy to specific nodes
./deploy.sh c1 c2    # Deploy only c1 and c2
```

### Deploy to individual nodes (if needed)
```bash
./deploy.sh c1
./deploy.sh c2
./deploy.sh c3
./deploy.sh c4
```

## ✅ Step 5: Verify Deployment

### Check SSH access
```bash
# SSH to individual nodes
ssh crussell@192.168.68.71  # c1
ssh crussell@192.168.68.72  # c2
ssh crussell@192.168.68.73  # c3
ssh crussell@192.168.68.74  # c4

# SSH via VIP (should connect to current master)
ssh crussell@192.168.68.70
```

### Check SeaweedFS cluster
```bash
# Check master status (from any node with master)
curl http://192.168.68.71:9333/cluster/status

# Check volume status
curl http://192.168.68.71:9333/dir/status

# Check filer status
curl http://192.168.68.71:8888/
```

### Check Keepalived status
```bash
# Check which node has the VIP
ssh crussell@192.168.68.71 "ip addr show | grep 192.168.68.70"
ssh crussell@192.168.68.72 "ip addr show | grep 192.168.68.70"
```

## 🔧 Step 6: Test High Availability

### Test VIP failover
```bash
# Connect to current VIP holder
ssh crussell@192.168.68.70

# Stop keepalived to test failover
sudo systemctl stop keepalived

# Check which node now has the VIP
ssh crussell@192.168.68.71 "ip addr show | grep 192.168.68.70"
ssh crussell@192.168.68.72 "ip addr show | grep 192.168.68.70"
```

## 📊 Cluster Architecture

### Node Roles
- **c1** (192.168.68.71): Master, Volume, Filer, Keepalived (Priority 120)
- **c2** (192.168.68.72): Master, Volume, Filer, Keepalived (Priority 110)  
- **c3** (192.168.68.73): Master, Volume, Keepalived (Priority 100)
- **c4** (192.168.68.74): Volume, Keepalived (Priority 90)

### Services
- **Virtual IP**: 192.168.68.70 (managed by Keepalived)
- **SeaweedFS Masters**: Ports 9333 on c1, c2, c3
- **SeaweedFS Volumes**: Port 8080 on all nodes
- **SeaweedFS Filers**: Port 8888 on c1, c2

### Storage
- **System Storage**: Btrfs on /dev/nvme0n1 (with subvolumes)
- **SeaweedFS Storage**: ext4 on /dev/nvme1n1 mounted at /var/lib/seaweedfs

## 🛠️ Troubleshooting

### Common Issues

1. **SSH connection refused**: Ensure target machine has SSH enabled and your key is authorized
2. **Secrets decryption failed**: Check age key path and permissions
3. **Flake check failed**: Run `nix flake check` to see specific errors
4. **SeaweedFS not starting**: Check logs with `journalctl -u seaweedfs-master`

### Useful Commands
```bash
# Check system logs
ssh crussell@192.168.68.71 "journalctl -xe"

# Check specific service status
ssh crussell@192.168.68.71 "systemctl status seaweedfs-master"
ssh crussell@192.168.68.71 "systemctl status keepalived"

# View current NixOS configuration
ssh crussell@192.168.68.71 "nixos-rebuild list-generations"
```

## 🔄 Making Changes

### Update configuration
```bash
# Edit configuration files
editor hosts/c1/configuration.nix

# Deploy changes
./deploy.sh c1
```

### Add new secrets
```bash
# Edit secrets (will be decrypted automatically)
sops secrets/secrets.yaml

# Deploy to apply changes
./deploy.sh
```

That's it! Your home cluster should now be running with high availability SeaweedFS storage and automatic failover via Keepalived. 🎉
