#!/usr/bin/env bash
set -e

# Quadlet files location for user services
QUADLET_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/containers/systemd"

echo "Installing Vicinae quadlet files to $QUADLET_DIR..."

# Create directory if it doesn't exist
mkdir -p "$QUADLET_DIR"

# Copy quadlet files
cp vicinae.container "$QUADLET_DIR/"
cp vicinae-config.volume "$QUADLET_DIR/"
cp vicinae-data.volume "$QUADLET_DIR/"
cp vicinae-cache.volume "$QUADLET_DIR/"

echo "Reloading systemd daemon..."
systemctl --user daemon-reload

echo ""
echo "Vicinae quadlet installed successfully!"
echo ""
echo "The service is configured to start automatically on login (WantedBy=default.target)."
echo ""
echo "To start Vicinae now:"
echo "  systemctl --user start vicinae.service"
echo ""
echo "To view logs:"
echo "  journalctl --user -u vicinae.service -f"
echo ""
echo "Or use the control script:"
echo "  ./vicinae-ctl.sh enable   # Start now"
echo "  ./vicinae-ctl.sh status   # Check status"
echo "  ./vicinae-ctl.sh logs     # View logs"

