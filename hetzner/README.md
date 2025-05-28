# nixos-anywhere Setup for Hetzner

This flake now includes nixos-anywhere support for deploying NixOS to remote servers, especially Hetzner Cloud.

## Prerequisites

1. **SSH Key**: Add your SSH public key to `configuration.nix` in the root user and admin user sections
2. **Target Server**: A server running any Linux distribution (will be completely replaced with NixOS)

## Quick Start

### Deploy to Hetzner Cloud

Use the included deployment script:

```bash
nix run .#deploy-hetzner -- <server-ip>
```

For example:
```bash
nix run .#deploy-hetzner -- 1.2.3.4
```

## Available Configurations

- **`hetzner-cloud`**: Optimized for Hetzner Cloud x86_64 servers

## Manual Deployment

If you prefer to run nixos-anywhere manually:

```bash
# Install nixos-anywhere
nix profile install github:nix-community/nixos-anywhere

# Deploy to Hetzner
nixos-anywhere --flake .#hetzner-cloud root@<server-ip>
```

## Customization

### Hetzner-Specific Settings

Edit `hetzner/default.nix` to customize:
- Disk partitioning (disko configuration)
- Network interface names
- Hardware-specific settings
- Basic system packages

### General Settings

Edit `hetzner/configuration.nix` for:
- Additional system packages
- User accounts
- SSH configuration
- Advanced system settings

## Disk Configuration

The default setup creates:
- Small boot partition for GRUB
- Single ext4 root partition using remaining space

To customize disk layout, modify the `disko.devices` section in `hetzner/default.nix`.

## Security Notes

- SSH password authentication is disabled by default
- Only SSH key authentication is allowed
- A sudo-enabled `admin` user is created
- Root login is allowed but only with SSH keys (prohibit-password mode)

## Troubleshooting

1. **SSH Key Issues**: Make sure your SSH key is properly added to both root and admin users in `hetzner/configuration.nix`
2. **Network Issues**: Hetzner Cloud uses `enp1s0` interface by default
3. **Disk Issues**: Default configuration assumes `/dev/sda` - adjust in `hetzner/default.nix` if different

## Files Overview

- `flake.nix`: Main flake with nixos-anywhere configuration
- `hetzner/default.nix`: Hetzner-specific module with disk and hardware setup
- `hetzner/configuration.nix`: User and system configuration 