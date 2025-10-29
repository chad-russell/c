## Nix configuration (flake-based)

This repo manages both Home Manager configurations (macOS + Linux) and NixOS systems using a single flake. Machines live under `machines/`, shared modules under `modules/`, and a small `lib/` ties it together.

### What to read first
- **`flake.nix`**: entry point; wires inputs, exports `homeConfigurations` and `nixosConfigurations`, devShells, and helper apps.
- **`lib/`**: small helpers to assemble configs
  - `lib/system.nix`: builds per-machine Home and (for Linux) NixOS configs
  - `lib/home.nix`: constructs a Home Manager config with shared modules and Stylix
  - `lib/nixos.nix`: constructs a NixOS config layering machine modules and shared system modules
  - `lib/modules.nix`: path helpers like `getHomeModuleDir`, `getMachineNixos`, etc.
- **`machines/<name>/`**: per-machine files
  - `default.nix`: declares machine metadata (system/arch, username, stateVersion, optional module lists)
  - `home.nix`: optional machine-specific Home Manager module
  - `configuration.nix` and `hardware-configuration.nix`: optional NixOS files for Linux hosts

## Layout
- **`machines/`**: one folder per machine (Darwin or Linux)
- **`modules/`**: reusable modules
  - `modules/home/*`: Home Manager modules; `modules/home/common/default.nix` composes the shared baseline
  - `modules/nixos/*`: NixOS modules; `modules/nixos/common/default.nix` composes the shared baseline
- **`lib/`**: light plumbing and path helpers

## Quickstart
- Format: `nix fmt` (formatter is set in `flake.nix`)
- Dev shell (age, git, gh, tailscale): `nix develop`
- Clean old Home Manager generations + GC: `nix run .#clean-home`

## Applying configurations
- Home Manager (macOS/Linux):
  - Switch: `home-manager switch --flake .#<machine-name>`
- NixOS (Linux machines that have `configuration.nix`):
  - Switch: `sudo nixos-rebuild switch --flake .#<machine-name>`

Note: Building a Linux machine’s NixOS output assumes the machine folder provides `configuration.nix` (and typically `hardware-configuration.nix`). Home Manager works with just `home.nix`.

## Adding a machine
1) Create a folder: `machines/<name>/`
2) Add `machines/<name>/default.nix` like:
```nix
{ self, ... }: {
  system = "aarch64-darwin"; # or "x86_64-linux"
  username = "your-user";
  stateVersion = "24.11";   # Home Manager state version

  # Optional: extend shared Home baseline
  homeModules = [
    (import (self.lib.modules.getHomeModule "desktop"))
  ];

  # Optional (Linux only): extra NixOS modules layered on top
  nixosModules = [ ];
}
```
3) Optionally add:
- `machines/<name>/home.nix` for machine-specific Home Manager tweaks
- `machines/<name>/configuration.nix` (+ `hardware-configuration.nix`) for NixOS hosts

## How composition works
- `lib/system.nix` exposes `mkSystem` and `mkSystems` used by `flake.nix`
  - For each machine, Home Manager modules are assembled by `lib/home.nix`:
    - Shared baseline: `modules/home/common/default.nix`
    - OS-specific baseline: `modules/home/darwin` or `modules/home/linux`
    - Machine module: `machines/<name>/home.nix` (if present)
    - Extras: Stylix (`inputs.stylix.homeModules.stylix`)
  - For Linux machines, `lib/nixos.nix` builds a NixOS config layering:
    - Shared baseline: `modules/nixos/common/default.nix`
    - Machine config: `machines/<name>/configuration.nix`
    - System user module: `modules/nixos/system/user.nix`

## Path helper cheatsheet (from `lib/modules.nix`)
- **Home**: `getHomeModule name`, `getHomeModuleDir name`
- **NixOS**: `getNixosModule name`, `getNixosModuleDir name`
- **Machines**: `getMachineHome name`, `getMachineNixos name`, `getMachineDefault name`

Prefer these helpers over relative paths so modules remain relocatable and easy to search.

## Secrets
- Default secrets file: `secrets/secrets.yaml` (referenced via `self.lib.modules.defaultSecretsFile`)

## Tips for LLMs (and humans)
- Start at `flake.nix`, then jump to `lib/system.nix` ➜ `lib/home.nix` / `lib/nixos.nix`.
- When adding features, prefer placing shared logic in `modules/home/*` or `modules/nixos/*` and keep `machines/*` minimal.
- Use `self.lib.modules.*` helpers for imports; avoid `../..` paths.

## Common tasks
- List available outputs: `nix flake show`
- Apply Home config for current host: `home-manager switch --flake .#<machine-name>`
- Apply NixOS config (Linux): `sudo nixos-rebuild switch --flake .#<machine-name>`
