# Home Compute Cluster

A NixOS-based home compute cluster with services running on Proxmox VMs.

## Architecture

This setup uses a **two-phase deployment approach**:

1. **Bootstrap Phase**: Deploy a minimal base VM image to Proxmox
2. **Operational Phase**: SSH into the VM and rebuild with the specific service configuration

This separation provides:
- Single source of truth for service configurations
- Clean separation between VM creation and service management  
- Standard `nixos-rebuild` workflow for updates
- Reduced complexity and duplication

## Quick Start

### 1. Bootstrap Phase

Build and deploy the bootstrap VM:

```bash
# Build the bootstrap image
nix build .#bootstrap

# Deploy to Proxmox (adapt for your setup)
# The result will be in ./result/
```

The bootstrap VM includes:
- Basic NixOS system with flakes enabled
- SSH access configured
- Git, curl, vim, htop
- Your user account with sudo access

### 2. Operational Phase

After the bootstrap VM is running:

```bash
# SSH into the new VM
ssh crussell@<VM_IP>

# Clone this repository
git clone <repository-url>
cd <repository-directory>

# Switch to the desired service configuration
sudo nixos-rebuild switch --flake .#jellyfin
# or
sudo nixos-rebuild switch --flake .#nginx  
# or
sudo nixos-rebuild switch --flake .#gateway
```

## Available Services

- **jellyfin**: Media server with GPU hardware acceleration + Jellyseerr
- **nginx**: Reverse proxy and web server
- **gateway**: Network gateway with Tailscale integration
- **cloud-proxy**: Minimal reverse proxy for cloud deployment

## Updating Services

To update a service after deployment:

```bash
# SSH into the service VM
ssh crussell@<VM_IP>

# Pull latest changes
git pull

# Rebuild with updated configuration
sudo nixos-rebuild switch --flake .#<service-name>
```

## Service Details

### Jellyfin VM
- **IP**: 192.168.1.203
- **Ports**: 8096 (Jellyfin), 5055 (Jellyseerr)
- **Features**: Intel GPU hardware acceleration, Podman containers
- **Storage**: `/media` for content, `/var/lib/jellyfin` for config

### Development Workflow

1. Modify service configurations in `modules/`
2. Test changes by rebuilding on the target VM
3. Commit and push changes
4. Pull and rebuild on other VMs as needed

## Tools

- `nix build .#bootstrap` - Build bootstrap VM image
- `nix build .#deploy-key` - Build age key deployment script  
- `nix build .#nixos-anywhere` - Build nixos-anywhere tool

## Network Configuration

Services use static IP assignments in the 192.168.1.x range. Adjust IP addresses in the respective module files as needed for your network.

## To Build on NixOS
```bash
nix build .#bootstrap
```

## To restore onto a proxmox node
```bash
qmrestore /var/lib/vz/dump/vzdump-qemu-nixos-*.vma.zst ID --storage vmstore --force
```

## More useful commands:
```bash
# Increase RAM to 4096 MB
qm set ID --memory 4096

# Set CPU cores
qm set ID --cores 2

# Expand the main disk (if needed)
qm resize ID virtio0 +50G
```

## Key Configuration Details & Troubleshooting Notes

Beyond the declarative NixOS configuration in `flake.nix`, several manual steps and considerations within the Proxmox VE environment and on client machines were crucial for this setup:

### 1. Proxmox VE VM Configuration

These settings are managed directly in the Proxmox VE web GUI for each VM:

*   **Unique MAC Addresses:** Each VM connected to the same Proxmox bridge (e.g., `vmbr0`) *must* have a unique MAC address. If VMs are cloned or created with default/zeroed MACs (e.g., `00:00:00:00:00:00`), they will fail to communicate properly. 
    *   **Fix:** Edit the VM's network hardware settings and either clear the MAC address field to let Proxmox auto-generate a unique one, or manually assign a unique MAC.
*   **Proxmox VE Firewall on VM Network Interface:** The `flake.nix` configures the firewall *inside* the NixOS guest. However, Proxmox VE also has its own firewall that can be enabled per VM network interface.
    *   **Fix/Check:** For inter-VM communication on the LAN (e.g., Traefik VM talking to Nginx VM), ensure the "Firewall" checkbox for the relevant network device (e.g., `net0`) in the VM's Hardware settings is either **unchecked**, or if checked, that appropriate "Allow" rules are in place in the Proxmox VE firewall settings for that VM to permit the necessary traffic (e.g., allow TCP port 80 from the Traefik VM's IP to the Nginx VM's IP).
*   **Network Bridge:** Ensure all VMs that need to communicate directly on the LAN are connected to the same Proxmox bridge (typically `vmbr0`).

### 2. Client DNS Configuration (for LAN Testing & Use)

*   **Setting Local DNS Server:** To make LAN clients use the AdGuard Home instance for local name resolution (e.g., `test.internal.crussell.io`), their DNS settings must point to the AdGuard Home VM's IP address (e.g., `192.168.68.212`). This can be done manually on the client or, for wider application, configured via your LAN's DHCP server.
*   **DNS Cache Flushing:** After changing DNS settings or when testing DNS propagation, flushing the client's DNS cache is often necessary.
    *   **macOS example:** `sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder` followed by `sudo killall -HUP mDNSResponder`


# 🛠️ Final Master Plan: Task List

## 🔧 Set Up Public Reverse Proxy (VPS)
- [ ] Install Traefik or Caddy
- [ ] Set up Route53 DNS challenge for Let's Encrypt
- [ ]  Route subdomains like jellyfin.crussell.io to internal services via Tailscale

## 🔧 Set Up Private Reverse Proxy (Proxmox VM)
- [ ] Install Traefik or Caddy
- [ ] Configure routes to LAN services like Paperless
- [ ] Optional: Serve fallback for public services if internet down

## 🧭 Set Up Split-Horizon DNS
- [ ] Install dnsmasq or CoreDNS on LAN box (can be same as proxy)
- [ ] Configure overrides for *.internal.crussell.io and optionally *.crussell.io
- [ ] Point LAN clients' DNS to it (via DHCP/router)

## 🧪 Test All Access Paths
- [ ] LAN with internet → works ✅
- [ ] LAN without internet → works ✅
- [ ] Remote (Tailscale) → works ✅
- [ ] Public users → works ✅


## Configuring iGPU passthrough for Intel
```bash
# Get correct ids:
lspci -n | grep 00:02.0

# On each node:
echo "blacklist i915" >> /etc/modprobe.d/blacklist.conf
echo "options vfio-pci ids=8086:3e92" >> /etc/modprobe.d/vfio.conf
update-initramfs -u -k all
reboot
```