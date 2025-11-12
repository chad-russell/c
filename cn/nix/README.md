# NixOS Homelab Configuration

This repository contains NixOS configurations for the homelab cluster.

## Structure

```
nix/
├── flake.nix                    # Single flake for all machines
├── flake.lock                   # Locked dependencies
├── common/                      # Shared configuration modules
│   ├── base-configuration.nix   # Common system settings
│   ├── hardware-configuration.nix # Hardware detection
│   ├── hardware-watchdog.nix    # Watchdog configuration
│   └── network-optimizations.nix # Network tuning
├── services/                    # Shared service modules
│   ├── karakeep.nix
│   ├── memos.nix
│   ├── n8n.nix
│   ├── ntfy.nix
│   ├── papra.nix
│   ├── pinepods.nix
│   └── searxng.nix
├── k2/                          # k2-specific configuration
│   ├── configuration.nix        # Machine config (hostname, IP, services)
│   └── disk-config.nix          # Disk partitioning
└── k3/                          # k3-specific configuration
    ├── configuration.nix        # Machine config (hostname, IP, services)
    └── disk-config.nix          # Disk partitioning
```

## Machines

### k2 (192.168.20.62)
- Services: karakeep, memos, ntfy, papra
- Disk: NVMe for OS, HDD (1.8T) at /srv

### k3 (192.168.20.63)
- Services: n8n, pinepods, searxng
- Disk: NVMe for OS, HDD (1.8T) at /srv

## Deployment

### Deploy k2
```bash
nixos-anywhere --flake .#k2 root@192.168.20.62
```

### Deploy k3
```bash
nixos-anywhere --flake .#k3 root@192.168.20.63
```

### Rebuild existing system
```bash
# On the target machine
nixos-rebuild switch --flake .#k2  # or .#k3
```

## Adding a New Machine

1. Create directory: `mkdir kN`
2. Create `kN/configuration.nix` (use k2 as template)
3. Create `kN/disk-config.nix` (use k2 as template)
4. Add to `flake.nix` outputs
5. Deploy with `nixos-anywhere --flake .#kN root@IP`

## Adding a New Service

1. Create service file in `services/` directory
2. Import it in the machine's `configuration.nix`
3. Deploy the configuration

