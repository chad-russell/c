# Homelab Deployment Framework - Implementation Plan

## Overview

A lightweight, declarative deployment system for managing Podman Quadlet services across multiple homelab machines using SSH and systemd.

## Core Philosophy

- **Declarative**: Machines config file is the source of truth
- **Git-based**: All configuration version controlled
- **SSH-based**: Remote management without additional agents
- **Systemd-native**: Leverage systemd for dependencies, restart policies, etc.
- **Idempotent**: Safe to run repeatedly
- **Modern & Type-safe**: Built with TypeScript/Bun for excellent DX and maintainability

## Technology Stack

- **Language**: TypeScript (runtime: Bun)
- **Config Format**: YAML (using js-yaml)
- **SSH**: node-ssh library
- **CLI Framework**: commander
- **Output Styling**: chalk (colored terminal output)
- **File Operations**: fast-glob
- **Target Systems**: Rootless Podman + systemd (SSH access only)

---

## MVP Scope (Phase 1)

### Project Structure

- [ ] TypeScript project setup (package.json, tsconfig.json)
- [ ] Source structure:
  ```
  src/
  ├── index.ts              # Main CLI entry point
  ├── commands/
  │   ├── deploy.ts         # Deploy command
  │   ├── status.ts         # Status command
  │   └── undeploy.ts       # Undeploy command
  ├── lib/
  │   ├── ssh.ts            # SSH operations
  │   ├── systemd.ts        # Systemd operations
  │   ├── config.ts         # Config loading/parsing
  │   ├── diff.ts           # State reconciliation
  │   └── validation.ts     # Quadlet file validation
  └── types.ts              # TypeScript type definitions
  ```

### Configuration

- [x] Git repository structure
- [ ] `machines/machines.yaml` - Machine and service definitions
- [ ] Machine definition TypeScript interface:
  - hostname/IP
  - SSH user
  - description
  - list of services to deploy
- [ ] Service naming convention (servicename.container, servicename-*.{container,volume,network})
- [ ] Config validation with Zod or similar

### Core Commands

#### Deploy Command
- [ ] `bun run deploy <machine>` - Main deployment command
  - [ ] Deploy to a single machine
  - [ ] Discover currently deployed services (via SSH)
  - [ ] Calculate diff (what to add, what to remove, what to update)
  - [ ] Remove services no longer in config
  - [ ] Validate quadlet files before deploying
  - [ ] Deploy new/updated services (copy → daemon-reload → restart)
  - [ ] Start/enable services
  - [ ] Report deployment status with colored output
  - [ ] `--dry-run` flag (show what would happen)
  - [ ] `--service <name>` flag (deploy only one service)

#### Status Command
- [ ] `bun run status <machine>` - Check deployment status
  - [ ] List deployed services
  - [ ] Show systemd service status
  - [ ] Compare with machines.yaml (drift detection)
  - [ ] Show service health (running/failed/stopped)

#### Undeploy Command
- [ ] `bun run undeploy <machine>` - Remove services
  - [ ] `--service <name>` flag to remove specific service
  - [ ] Stop services
  - [ ] Disable services
  - [ ] Remove quadlet files
  - [ ] Daemon reload

### Library Modules

#### SSH Module (`src/lib/ssh.ts`)
- [ ] Connection management with node-ssh
- [ ] Connection testing/validation
- [ ] Remote command execution
- [ ] File transfer (SFTP)
- [ ] Error handling and retries

#### Systemd Module (`src/lib/systemd.ts`)
- [ ] List quadlet files remotely
- [ ] Parse service names from filenames
- [ ] Start/stop/enable/disable services (via SSH)
- [ ] Daemon reload (via SSH)
- [ ] Service status checking
- [ ] Get service logs

#### Config Module (`src/lib/config.ts`)
- [ ] Load and parse machines.yaml
- [ ] Type validation
- [ ] Get machine configuration by name
- [ ] List all machines

#### Diff Module (`src/lib/diff.ts`)
- [ ] Compare desired vs actual state
- [ ] Detect file changes (checksums via SSH)
- [ ] Generate deployment plan
- [ ] Return list of services to add/remove/update

#### Validation Module (`src/lib/validation.ts`)
- [ ] Validate quadlet file syntax
- [ ] Check for required fields
- [ ] Validate service naming conventions
- [ ] Pre-deployment validation

### Documentation

- [ ] Update main README.md with deployment workflow
- [ ] Add usage examples
- [ ] Document machines.yaml format
- [ ] Add troubleshooting section

### Testing

- [ ] Test deploy to single machine
- [ ] Test service removal
- [ ] Test re-deployment (idempotency)
- [ ] Test dry-run mode
- [ ] Test error handling (SSH failures, service failures)

---

## Future Enhancements (Post-MVP)

### Phase 2: Secrets Management

- [ ] Secrets definition format (separate from machines.yaml)
- [ ] Secure secrets storage (encrypted with git-crypt or sops)
- [ ] Secrets injection into environment variables
- [ ] Secrets rotation workflow
- [ ] Per-machine secrets vs shared secrets

### Phase 3: Backup & Recovery

- [ ] Volume backup commands
  - [ ] `scripts/backup` - Backup volumes from a machine
  - [ ] Configurable backup destinations
  - [ ] Incremental backups (rsync-based)
- [ ] Configuration snapshot/restore
  - [ ] Snapshot current state before deployment
  - [ ] Rollback to previous configuration
- [ ] Disaster recovery documentation

### Phase 4: Health Checks & Monitoring

- [ ] Service health check definitions
  - [ ] HTTP endpoint checks
  - [ ] Port availability checks
  - [ ] Container health status
- [ ] `scripts/healthcheck` - Run health checks across machines
- [ ] Alerting on failures (email, webhook, etc.)
- [ ] Dashboard/status page generation

### Phase 5: Logs & Observability

- [ ] `scripts/logs` - Fetch logs from remote services
  - [ ] Follow logs in real-time
  - [ ] Search across machines
  - [ ] Time-range filtering
- [ ] Log aggregation to central location
- [ ] Log rotation management
- [ ] Metrics collection (podman stats)

### Phase 6: Advanced Features

- [ ] Pre/post deployment hooks
  - [ ] Per-service hooks
  - [ ] Per-machine hooks
  - [ ] Custom validation scripts
- [ ] Service templates (parameterized services)
- [ ] Environment-specific configs (dev/staging/prod)
- [ ] Canary deployments (deploy to one machine, verify, then others)
- [ ] Machine groups (deploy to multiple machines at once)
- [ ] Web UI for deployment management
- [ ] Notification integrations (Discord, Slack, etc.)

---

## Technical Decisions

### Implementation Language

- **Decision**: TypeScript with Bun runtime ✅
- **Rationale**: Type safety, excellent DX, modern tooling, only runs locally (no runtime needed on targets)
- **Alternative considered**: Bash (too error-prone), Rust (overkill), Go (good but prefer TS)

### Deployment Model

- **Decision**: Rootless only (`systemctl --user`) ✅
- **Rationale**: Better security, no root access needed, aligns with homelab best practices
- **Future**: Could add rootful support in Phase 2 if needed

### Service Metadata

- **Decision**: No additional metadata files needed ✅
- **Rationale**: Quadlet files contain all necessary information
- **Format**: Standard systemd unit file syntax + Podman Quadlet extensions

### Update Strategy

- **Decision**: Copy files → daemon-reload → restart ✅
- **Rationale**: Simpler than stop/remove/start cycle
- **Fallback**: If this causes issues, can add full stop/remove/start cycle

### Validation

- **Decision**: Validate all quadlet files before deployment ✅
- **Method**: Parse files, check syntax, validate required fields
- **Future**: Could integrate with podman-system-generator for deeper validation

### File Change Detection

- **Method**: Use checksums (sha256) to detect if files changed
- **Optimization**: Only copy and reload if changes detected
- **Implementation**: Compute local checksum, compare with remote via SSH

### Service Dependencies

- **Method**: Use systemd `After=` and `Requires=` in quadlet files
- **No custom dependency resolution**: Let systemd handle the ordering
- **Deployment order**: Deploy all services, systemd figures out startup order

### Error Handling

- **Strategy**: Continue on individual service failures, collect and report all errors at end
- **Exit codes**: Non-zero if any service fails
- **Output**: Use chalk for colored error/warning/success messages
- **Logging**: Verbose mode (`--verbose` flag) for debugging

### Concurrency

- **MVP**: Serial deployment (one service at a time)
- **Rationale**: Simpler, easier to debug, sufficient for homelab scale
- **Future**: Parallel deployment where dependencies allow

---

## Success Criteria for MVP

- [ ] Can define machines and their services in YAML
- [ ] Can deploy all services to a machine with one command
- [ ] Can remove services that are no longer in config
- [ ] Can check status of deployed services
- [ ] Can undeploy specific services
- [ ] Dry-run mode works correctly
- [ ] Idempotent: running deploy twice does nothing on second run
- [ ] Clear error messages on failures
- [ ] Documentation covers common workflows

---

## Timeline Estimate (MVP)

- Project setup (package.json, tsconfig, dependencies): 30 minutes
- Type definitions and config module: 30 minutes
- SSH and systemd library modules: 1-2 hours
- Deploy command implementation: 2-3 hours
- Status and undeploy commands: 1-2 hours
- Validation module: 1 hour
- Testing & refinement: 1-2 hours
- Documentation: 1 hour

**Total MVP**: ~7-11 hours

---

## Development Notes

### Code Style
- Use strict TypeScript configuration
- Prefer functional programming patterns where appropriate
- Add JSDoc comments for public APIs
- Use async/await for all async operations
- Handle errors with proper try/catch and typed error objects

### Libraries to Use
- `node-ssh`: SSH connection management
- `js-yaml`: YAML parsing
- `commander`: CLI framework
- `chalk`: Terminal colors
- `fast-glob`: File pattern matching
- `zod` (optional): Runtime type validation

### Best Practices
- Validate all inputs (config files, command arguments)
- Use colored output (chalk): green=success, red=error, yellow=warning, blue=info
- Add `--verbose` flag for detailed logging
- Proper error messages with actionable suggestions
- Exit codes: 0 = success, 1 = error, 2 = validation error
- Use TypeScript's strict mode for maximum type safety

### Project Commands
```bash
bun install              # Install dependencies
bun run deploy           # Run deploy command
bun run status           # Run status command  
bun run undeploy         # Run undeploy command
bun build                # Build to dist/
bun test                 # Run tests (future)
```

### Optional: Standalone Binary
```bash
bun build --compile src/index.ts --outfile homelab
# Creates standalone executable, no bun runtime needed
```

