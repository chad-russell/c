# Homelab Services

Declarative deployment system for managing Podman Quadlet services across multiple homelab machines.

## Philosophy

This setup uses **Podman Quadlets** with a custom TypeScript deployment tool for:
- **Declarative configuration** - Define machines and their services in YAML
- **Git-based infrastructure** - All configs version controlled
- **Rootless containers** - Better security, no root required
- **SSH-based deployment** - No agents needed on target machines
- **Native systemd integration** - Automatic restarts and dependencies

## Quick Start

### 1. Configure Your Machines

Edit `machines/machines.yaml`:

```yaml
machines:
  homelab-main:
    hostname: 192.168.1.10
    user: youruser
    description: "Main server"
    services:
      - pinepods
```

### 2. Sync Services (Terraform-style)

```bash
# List configured machines
bun run src/index.ts list

# Sync machine state with configuration (shows plan, asks for confirmation)
bun run src/index.ts sync homelab-main

# Sync without confirmation
bun run src/index.ts sync homelab-main --yes

# Dry-run (see what would change)
bun run src/index.ts sync homelab-main --dry-run

# Sync specific service only
bun run src/index.ts sync homelab-main --service pinepods

# Check deployment status
bun run src/index.ts status homelab-main
```

The `sync` command:
- Shows you what will be added/removed (like Terraform plan)
- Asks for confirmation before making changes
- Removes services no longer in configuration
- Adds new services from configuration
- Properly stops all related systemd services before cleanup

## Services

- **[PinePods](services/pinepods/)** - Podcast management system with multi-user support

## Features

✅ **Declarative** - Machines config defines desired state  
✅ **Idempotent** - Safe to run repeatedly  
✅ **SSH-based** - Works with Tailscale SSH, key-based auth  
✅ **Automatic cleanup** - Removes services no longer in config  
✅ **Type-safe** - Written in TypeScript with validation  
✅ **Rootless** - All containers run without root

## Prerequisites

- **Bun** runtime (for deployment tool)
- **Podman** 4.4+ on target machines
- **SSH access** to target machines
- **systemd** on target machines

## Documentation

- [PLAN.md](PLAN.md) - Implementation plan and roadmap
- [Podman Quadlet Reference](docs/quadlet.md) - Complete Quadlet documentation
- [Volume Backup & Migration](docs/VOLUMES.md) - How to backup and migrate data
- [Service READMEs](services/) - Individual service documentation

## Project Structure

```
/home/crussell/Code/c/
├── machines/
│   └── machines.yaml          # Machine and service definitions
├── services/
│   └── pinepods/             # Service quadlet files
│       ├── *.container
│       ├── *.network
│       └── *.volume
├── src/
│   ├── index.ts              # CLI entry point
│   ├── commands/             # Deploy, status, undeploy
│   └── lib/                  # Core functionality
└── docs/                      # Documentation
```

## How It Works

1. **Define** machines and services in `machines/machines.yaml`
2. **Deploy** command:
   - Validates services locally
   - Connects via SSH
   - Uploads quadlet files to `~/.config/containers/systemd/`
   - Reloads systemd daemon
   - Starts services
3. **Systemd** manages lifecycle (restarts, dependencies, etc.)
4. **Podman** runs rootless containers

## Roadmap

**MVP (Complete)** ✅
- Deploy, status, and undeploy commands
- Multi-machine support
- SSH-based deployment
- Dry-run mode

**Phase 2 (Planned)**
- Automated volume backups
- Secrets management
- Deploy with volume restore

**Phase 3 (Future)**
- Health checks and monitoring
- Log aggregation
- Incremental backups

See [PLAN.md](PLAN.md) for details.

## Contributing

This is a personal homelab project, but feel free to fork and adapt for your own use!

## License

Configuration files in this repository are provided as-is for personal and educational use.

