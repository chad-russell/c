# Machines Configuration

This directory contains the configuration for all machines in your homelab.

## machines.yaml Format

```yaml
machines:
  machine-name:
    hostname: 192.168.1.10        # IP address or hostname
    user: username                # SSH user to connect as
    description: "Description"    # Optional human-readable description
    services:                     # List of services to deploy
      - service1
      - service2
```

## Example Configuration

```yaml
machines:
  homelab-main:
    hostname: 192.168.1.10
    user: crussell
    description: "Main server - high uptime services"
    services:
      - pinepods
      - nextcloud

  homelab-media:
    hostname: 192.168.1.20
    user: crussell
    description: "Media server"
    services:
      - jellyfin
      - sonarr
```

## Service Names

Service names must match directory names in the `services/` directory. For example, if you have `services/pinepods/`, the service name is `pinepods`.

## SSH Authentication

The deployment tool uses SSH key-based authentication. Make sure:
1. You have SSH keys set up (`~/.ssh/id_rsa` or similar)
2. Your public key is in the target machine's `~/.ssh/authorized_keys`
3. You can SSH to the machine without a password prompt

Test your connection:
```bash
ssh username@hostname
```

## Getting Started

1. Copy `machines.yaml` and uncomment the example configurations
2. Update hostnames, usernames, and service lists for your machines
3. Test your configuration:
   ```bash
   bun run list
   ```
4. Deploy to a machine:
   ```bash
   bun run deploy machine-name
   ```

