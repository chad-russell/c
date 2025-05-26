## To Build on NixOS
```bash
nix build .#proxmoxImage
```

## To restore onto a proxmox node
```bash
qmrestore /var/lib/vz/dump/vzdump-qemu-nixos-*.vma.zst 103 --storage vmstore --force
```

## More useful commands:
```bash
# Increase RAM to 4096 MB
qm set 101 --memory 4096

# Set CPU cores
qm set 101 --cores 2

# Expand the main disk (if needed)
qm resize 101 virito0 +50G
```


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
- [ ] Point LAN clients’ DNS to it (via DHCP/router)

## 🧪 Test All Access Paths
- [ ] LAN with internet → works ✅
- [ ] LAN without internet → works ✅
- [ ] Remote (Tailscale) → works ✅
- [ ] Public users → works ✅
