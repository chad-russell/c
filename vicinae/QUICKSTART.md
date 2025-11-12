# Vicinae Quickstart

## First Time Setup

```bash
# 1. Build the container (takes 10-15 minutes)
./build_container.sh

# 2. Install systemd quadlet
./install-quadlet.sh

# 3. Enable and start Vicinae
systemctl --user enable --now vicinae.service
```

## Daily Usage

```bash
# View logs
journalctl --user -u vicinae.service -f

# Restart
systemctl --user restart vicinae.service

# Stop
systemctl --user stop vicinae.service

# Check status
systemctl --user status vicinae.service
```

## Updating Vicinae

```bash
# Rebuild with latest code
podman rmi localhost/vicinae-runtime:latest
./build_container.sh

# Restart service
systemctl --user restart vicinae.service
```

## Uninstall

```bash
# Stop and disable service
systemctl --user disable --now vicinae.service

# Remove quadlet files
rm -rf ~/.config/containers/systemd/vicinae*

# Reload systemd
systemctl --user daemon-reload

# Remove container and volumes
podman rm -f vicinae
podman volume rm vicinae-config vicinae-data vicinae-cache

# Remove image
podman rmi localhost/vicinae-runtime:latest
```


