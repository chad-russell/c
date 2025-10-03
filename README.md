# Homelab Services

This repository tracks my homelab services using Podman Quadlets for containerized deployments.

## Philosophy

This setup uses **Podman Quadlets** instead of Docker Compose for:
- Native systemd integration
- Rootless container support
- Better security through SELinux integration
- Automatic service management and restart policies
- No daemon required

## Services

- **[PinePods](services/pinepods/)** - Podcast management system with multi-user support

## Quick Start

Each service has its own directory under `services/` with:
- Quadlet configuration files (`.container`, `.network`, `.volume`)
- Service-specific README with setup instructions

See individual service READMEs for installation and configuration details.

## Prerequisites

- Podman 4.4+ (for Quadlet support)
- systemd
- Basic understanding of systemd unit files

## General Deployment Pattern

For rootless deployment (recommended):
```bash
# Copy quadlet files to user systemd directory
mkdir -p ~/.config/containers/systemd/
cp services/<service>/*.{container,network,volume} ~/.config/containers/systemd/

# Reload systemd
systemctl --user daemon-reload

# Start services
systemctl --user start <service>.service

# Enable on boot (requires loginctl enable-linger)
loginctl enable-linger $USER
systemctl --user enable <service>.service
```

## Documentation

- [Podman Quadlet Reference](docs/quadlet.md) - Complete Quadlet documentation

## Contributing

Feel free to use this as a template for your own homelab. Each service is self-contained and can be adapted to your needs.

## License

Configuration files in this repository are provided as-is for personal and educational use.

