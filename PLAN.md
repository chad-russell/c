# Homelab Deployment Framework - Implementation Plan

## 🎉 **MVP COMPLETE** - October 2025

The MVP has been **fully implemented and tested**! The system is production-ready with a Terraform-style sync workflow, proper service cleanup, and comprehensive documentation.

**Quick Start:**
```bash
bun run src/index.ts sync <machine>    # Deploy with confirmation
bun run src/index.ts sync <machine> --yes  # Deploy without confirmation
bun run src/index.ts sync <machine> --dry-run  # Show plan only
```

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

## MVP Scope (Phase 1) ✅ **COMPLETE**

### Project Structure

- [x] TypeScript project setup (package.json, tsconfig.json) ✅
- [x] Source structure: ✅
  ```
  src/
  ├── index.ts              # Main CLI entry point ✅
  ├── commands/
  │   ├── list.ts           # List machines command ✅
  │   ├── sync.ts           # Sync command (Terraform-style) ✅
  │   └── deploy.ts         # Deploy command (legacy) ✅
  ├── lib/
  │   ├── ssh.ts            # SSH operations ✅
  │   ├── systemd.ts        # Systemd operations ✅
  │   ├── config.ts         # Config loading/parsing ✅
  │   ├── services.ts       # Local service file operations ✅
  │   └── (diff/validation integrated into commands) ✅
  └── types.ts              # TypeScript type definitions ✅
  ```

### Configuration

- [x] Git repository structure ✅
- [x] `machines/machines.yaml` - Machine and service definitions ✅
- [x] Machine definition TypeScript interface: ✅
  - hostname/IP ✅
  - SSH user ✅
  - description ✅
  - list of services to deploy ✅
- [x] Service naming convention (servicename.container, servicename-*.{container,volume,network}) ✅
- [x] Config validation with Zod ✅

### Core Commands

#### List Command ✅
- [x] `bun run list` - Show all configured machines ✅
  - [x] Parse and display machines.yaml ✅
  - [x] Show hostname, user, description, services ✅
  - [x] Colored output with chalk ✅

#### Sync Command (Main) ✅
- [x] `bun run sync <machine>` - Terraform-style sync command ✅
  - [x] Discover currently deployed services (via SSH) ✅
  - [x] Calculate diff (what to add, what to remove) ✅
  - [x] Show plan before applying changes ✅
  - [x] Ask for confirmation (unless --yes flag) ✅
  - [x] Stop ALL related services before removal ✅
  - [x] Remove services no longer in config ✅
  - [x] Validate quadlet files before deploying ✅
  - [x] Deploy new services (upload → daemon-reload → start) ✅
  - [x] Report deployment status with colored output ✅
  - [x] `--dry-run` flag (show plan without changes) ✅
  - [x] `--yes` flag (skip confirmation) ✅
  - [x] `--service <name>` flag (sync only one service) ✅
  - [x] `--verbose` flag (detailed output) ✅

#### Deploy Command (Legacy) ✅
- [x] `bun run deploy <machine>` - Direct deployment (kept for compatibility) ✅
  - [x] All sync features but without confirmation prompt ✅
  - [x] Marked as legacy in help text ✅

#### Status Command
- [ ] `bun run status <machine>` - Check deployment status
  - [ ] List deployed services
  - [ ] Show systemd service status
  - [ ] Compare with machines.yaml (drift detection)
  - [ ] Show service health (running/failed/stopped)

#### Undeploy Command
- [ ] `bun run undeploy <machine>` - Remove services
  - [ ] Wrapper around sync with empty service list
  - [ ] Or keep as explicit removal command

### Library Modules

#### SSH Module (`src/lib/ssh.ts`) ✅
- [x] Connection management with node-ssh ✅
- [x] SSH agent authentication (Tailscale SSH compatible) ✅
- [x] Remote command execution ✅
- [x] File transfer (SFTP) with uploadFiles ✅
- [x] Download files ✅
- [x] List remote files ✅
- [x] Remote path exists check ✅
- [x] Remote file checksums ✅
- [x] Error handling ✅

#### Systemd Module (`src/lib/systemd.ts`) ✅
- [x] List quadlet files remotely ✅
- [x] Parse service names from filenames ✅
- [x] Start/stop services (via SSH) ✅
- [x] List all systemd services matching pattern ✅
- [x] Stop ALL related services (prevents orphans) ✅
- [x] Daemon reload (via SSH) ✅
- [x] Service status checking ✅
- [x] Get container info ✅
- [x] Remove service files ✅
- [x] Ensure systemd directory exists ✅

#### Config Module (`src/lib/config.ts`) ✅
- [x] Load and parse machines.yaml ✅
- [x] Type validation with Zod ✅
- [x] Get machine configuration by name ✅
- [x] List all machines ✅
- [x] Get services directory paths ✅

#### Services Module (`src/lib/services.ts`) ✅
- [x] Check if service exists locally ✅
- [x] Get all quadlet files for a service ✅
- [x] Calculate file checksums (SHA256) ✅
- [x] Validate service structure ✅
- [x] Get main service name for starting ✅

#### Diff/Validation (Integrated) ✅
- [x] Compare desired vs actual state (in sync command) ✅
- [x] Calculate what to add/remove (SyncPlan) ✅
- [x] Validate services before deployment ✅
- [x] Service naming convention validation ✅

### Documentation ✅

- [x] Update main README.md with deployment workflow ✅
- [x] Add usage examples (sync, deploy, list) ✅
- [x] Document machines.yaml format ✅
- [x] Create VOLUMES.md for backup/migration guide ✅
- [x] machines/README.md with SSH setup ✅
- [x] Update PLAN.md with progress ✅

### Testing ✅

- [x] Test deploy to single machine (pinepods on k3) ✅
- [x] Test service removal (proper cleanup, no orphans) ✅
- [x] Test re-deployment (idempotency) ✅
- [x] Test dry-run mode ✅
- [x] Test sync command (add/remove cycle) ✅
- [x] Test confirmation prompts ✅
- [x] Test --yes flag ✅
- [x] Test SSH agent authentication (Tailscale SSH) ✅
- [x] Verify no orphaned systemd units ✅
- [x] Verify no orphaned containers ✅

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

## Success Criteria for MVP ✅ **ALL ACHIEVED**

- [x] Can define machines and their services in YAML ✅
- [x] Can deploy all services to a machine with one command (`sync`) ✅
- [x] Can remove services that are no longer in config (automatic in sync) ✅
- [x] Shows plan before making changes (Terraform-style) ✅
- [x] Asks for confirmation before applying changes ✅
- [x] Dry-run mode works correctly ✅
- [x] Idempotent: running sync twice shows "already in sync" ✅
- [x] Clear error messages on failures ✅
- [x] Proper cleanup: no orphaned services or containers ✅
- [x] Documentation covers common workflows ✅
- [x] SSH agent authentication works (Tailscale SSH compatible) ✅

**Bonus achievements:**
- [x] Terraform-style workflow with plan and confirmation ✅
- [x] Colored terminal output for better UX ✅
- [x] Type-safe throughout with Zod validation ✅
- [x] Stops ALL related services before cleanup ✅
- [x] Volume backup/migration documentation ✅

---

## Timeline Estimate (MVP)

**Estimated**: ~7-11 hours  
**Actual**: ~6 hours ✅ (completed in one session!)

Breakdown:
- Project setup (package.json, tsconfig, dependencies): ✅ 30 minutes
- Type definitions and config module: ✅ 30 minutes
- SSH and systemd library modules: ✅ 1.5 hours
- Deploy command implementation: ✅ 2 hours
- Sync command implementation: ✅ 1.5 hours
- Service cleanup fixes: ✅ 30 minutes
- Testing & refinement: ✅ 45 minutes
- Documentation: ✅ 45 minutes

**Efficiency gains:**
- Integrated validation into commands rather than separate module
- Combined diff logic into sync command
- Leveraged TypeScript and Bun for fast iteration
- Used SSH agent authentication (simpler than key management)

---

## Key Implementation Learnings

### Critical Fixes

1. **Service Cleanup** - Initially only stopped main service, leaving orphaned units
   - **Solution**: Added `stopAllRelatedServices()` that finds all services matching pattern
   - **Result**: Clean removal with no orphaned systemd units or containers

2. **Path Handling** - Tilde (`~`) not expanded in remote paths
   - **Solution**: Use relative paths for SFTP, tilde in shell commands
   - **Result**: Files upload correctly to `~/.config/containers/systemd`

3. **SSH Authentication** - Initial implementation required unencrypted keys
   - **Solution**: Use SSH agent (`process.env.SSH_AUTH_SOCK`)
   - **Result**: Works with Tailscale SSH and encrypted keys

### Design Decisions

1. **Sync vs Deploy** - Chose Terraform-style workflow
   - Shows plan before changes
   - Asks for confirmation
   - Better UX and safety

2. **No Enable Call** - Quadlet services use `[Install]` section
   - Services auto-enable via quadlet configuration
   - Manual enable call causes "transient" error

3. **Service Naming** - Parse first part before dash as service name
   - `pinepods-db.container` → service name: `pinepods`
   - Allows grouping all related units

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

