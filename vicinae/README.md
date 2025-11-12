# Vicinae Container Setup

This directory contains scripts and configuration to build and run [Vicinae](https://vicinae.io) in a containerized environment using Podman.

## Quick Start (Easy Mode)

Use the control script for simplified management:

```bash
# First time setup
./vicinae-ctl.sh build      # Build the container
./vicinae-ctl.sh install    # Install systemd quadlet
./vicinae-ctl.sh enable     # Enable and start service

# Daily usage
./vicinae-ctl.sh status     # Check status
./vicinae-ctl.sh logs       # View logs
./vicinae-ctl.sh restart    # Restart service
./vicinae-ctl.sh update     # Update to latest version

# See all commands
./vicinae-ctl.sh help
```

## Building

To build the Vicinae container:

```bash
./build_container.sh
```

This will create a `localhost/vicinae-runtime:latest` image. The build process:
- Uses Fedora 42 as the base
- Builds Vicinae from source with protobuf, abseil, cmark-gfm, and minizip statically linked
- Creates a runtime image with only the necessary dependencies

**Note:** The first build can take 10-15 minutes depending on your system.

## Running

### Option 1: Manual Run (Script)

Run Vicinae directly using the run script:

```bash
./run_container.sh
```

**Requirements:**
- Must be run from within a Wayland graphical session (not SSH/TTY)
- The script will verify the Wayland socket exists before starting

To stop the container:
```bash
podman stop vicinae
podman rm vicinae
```

### Option 2: Systemd Quadlet (Recommended)

For automatic startup and management via systemd:

#### Install the Quadlet

```bash
./install-quadlet.sh
```

This installs the quadlet files to `~/.config/containers/systemd/`.

#### Enable and Start Vicinae

```bash
systemctl --user enable --now vicinae.service
```

#### View Logs

```bash
journalctl --user -u vicinae.service -f
```

#### Stop Vicinae

```bash
systemctl --user stop vicinae.service
```

#### Disable Autostart

```bash
systemctl --user disable vicinae.service
```

## Files

- **`build_container.sh`** - Builds the container image
- **`Containerfile`** - Multi-stage container definition
- **`run_container.sh`** - Manual container run script
- **`vicinae.container`** - Systemd quadlet container definition
- **`vicinae-*.volume`** - Persistent volume definitions for config/data/cache
- **`install-quadlet.sh`** - Installs quadlet files to systemd
- **`vicinae-ctl.sh`** - Control script for managing Vicinae
- **`FLATPAK_SETUP.md`** - Guide for configuring Flatpak app launching

## Configuration

Vicinae configuration is stored in persistent volumes:
- **Config**: `vicinae-config` → `/home/vicinae/.config`
- **Data**: `vicinae-data` → `/home/vicinae/.local/share`
- **Cache**: `vicinae-cache` → `/home/vicinae/.cache`

### Flatpak Integration

The container can discover and launch your Flatpak applications. After initial setup, configure the **Launch Prefix** in Vicinae settings:

**Settings → Applications → Launch Prefix**: `flatpak-spawn --host`

See `FLATPAK_SETUP.md` for details.

## Troubleshooting

### Build Fails with Protobuf Errors

The Containerfile is configured to build protobuf from source (not use system protobuf) to avoid include path conflicts. This is the recommended configuration per Vicinae's documentation.

### Container Won't Start - Wayland Socket Error

Make sure you're running from a Wayland session:
```bash
echo $WAYLAND_DISPLAY  # Should show something like "wayland-0"
echo $XDG_RUNTIME_DIR  # Should show "/run/user/1000" or similar
```

If empty, you're not in a graphical Wayland session.

### Systemd Service Fails

Check the logs:
```bash
journalctl --user -u vicinae.service --no-pager
```

Make sure your compositor is running as a systemd service (e.g., with [uwsm](https://github.com/Vladimir-csp/uwsm)).

## Updating

To update Vicinae:

1. Remove the old image:
   ```bash
   podman rmi localhost/vicinae-runtime:latest
   ```

2. Rebuild:
   ```bash
   ./build_container.sh
   ```

3. Restart the service:
   ```bash
   systemctl --user restart vicinae.service
   ```

## References

- [Vicinae Official Site](https://vicinae.io)
- [Vicinae GitHub](https://github.com/vicinaehq/vicinae)
- [Build from Source Docs](https://vicinae.io/docs/build-from-source)
- [Podman Quadlet Documentation](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html)

