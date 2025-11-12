#!/usr/bin/env bash
# Vicinae Container Control Script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

show_usage() {
    cat << EOF
Vicinae Container Control

Usage: $0 <command>

Commands:
  build        Build the Vicinae container image
  install      Install systemd quadlet files
  enable       Enable and start Vicinae service
  disable      Disable and stop Vicinae service
  start        Start Vicinae service
  stop         Stop Vicinae service
  restart      Restart Vicinae service
  status       Show Vicinae service status
  logs         Show Vicinae logs (follow mode)
  logs-all     Show all Vicinae logs
  update       Update Vicinae (rebuild and restart)
  uninstall    Remove everything (service, volumes, image)
  
Examples:
  $0 build            # Build the container
  $0 install          # Install quadlet
  $0 enable           # Enable and start service
  $0 logs             # Follow logs in real-time
  $0 update           # Update to latest version

EOF
}

cmd_build() {
    echo "Building Vicinae container..."
    ./build_container.sh
}

cmd_install() {
    echo "Installing systemd quadlet..."
    ./install-quadlet.sh
}

cmd_enable() {
    echo "Starting Vicinae service..."
    echo "(Quadlets auto-enable when WantedBy=default.target is set)"
    systemctl --user start vicinae.service --no-block
    echo ""
    echo "Vicinae is starting up (this takes a few seconds)..."
    echo "It will now start automatically on login."
    echo ""
    echo "Check status with: $0 status"
    echo "View logs with: $0 logs"
}

cmd_disable() {
    echo "Stopping Vicinae service and preventing autostart..."
    systemctl --user stop vicinae.service
    
    # Remove the WantedBy from quadlet to prevent autostart
    QUADLET_FILE="$HOME/.config/containers/systemd/vicinae.container"
    if [ -f "$QUADLET_FILE" ]; then
        sed -i '/^WantedBy=/d' "$QUADLET_FILE"
        systemctl --user daemon-reload
        echo "Removed autostart (WantedBy=default.target)"
    fi
    
    echo "Vicinae disabled and stopped"
}

cmd_start() {
    systemctl --user start vicinae.service --no-block
    echo "Vicinae is starting up..."
    echo "Check status with: $0 status"
}

cmd_stop() {
    systemctl --user stop vicinae.service
    echo "Vicinae stopped"
}

cmd_restart() {
    systemctl --user restart vicinae.service --no-block
    echo "Vicinae is restarting..."
    echo "Check status with: $0 status"
}

cmd_status() {
    systemctl --user status vicinae.service
}

cmd_logs() {
    echo "Following Vicinae logs (Ctrl+C to exit)..."
    journalctl --user -u vicinae.service -f
}

cmd_logs_all() {
    journalctl --user -u vicinae.service --no-pager
}

cmd_update() {
    echo "Updating Vicinae..."
    echo ""
    echo "Step 1/3: Stopping service..."
    systemctl --user stop vicinae.service 2>/dev/null || true
    
    echo "Step 2/3: Rebuilding image..."
    podman rmi localhost/vicinae-runtime:latest 2>/dev/null || true
    ./build_container.sh
    
    echo "Step 3/3: Restarting service..."
    systemctl --user start vicinae.service
    
    echo ""
    echo "Update complete!"
}

cmd_uninstall() {
    echo "This will remove:"
    echo "  - Vicinae systemd service"
    echo "  - Quadlet configuration files"
    echo "  - Container and volumes (config/data/cache)"
    echo "  - Container image"
    echo ""
    read -p "Are you sure? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        echo "Cancelled."
        exit 0
    fi
    
    echo ""
    echo "Uninstalling Vicinae..."
    
    echo "Stopping and disabling service..."
    systemctl --user disable --now vicinae.service 2>/dev/null || true
    
    echo "Removing quadlet files..."
    rm -f ~/.config/containers/systemd/vicinae.container
    rm -f ~/.config/containers/systemd/vicinae-*.volume
    
    echo "Reloading systemd..."
    systemctl --user daemon-reload
    
    echo "Removing container and volumes..."
    podman rm -f vicinae 2>/dev/null || true
    podman volume rm vicinae-config vicinae-data vicinae-cache 2>/dev/null || true
    
    echo "Removing image..."
    podman rmi localhost/vicinae-runtime:latest 2>/dev/null || true
    
    echo ""
    echo "Uninstall complete!"
}

# Main command dispatcher
case "${1:-}" in
    build)
        cmd_build
        ;;
    install)
        cmd_install
        ;;
    enable)
        cmd_enable
        ;;
    disable)
        cmd_disable
        ;;
    start)
        cmd_start
        ;;
    stop)
        cmd_stop
        ;;
    restart)
        cmd_restart
        ;;
    status)
        cmd_status
        ;;
    logs)
        cmd_logs
        ;;
    logs-all)
        cmd_logs_all
        ;;
    update)
        cmd_update
        ;;
    uninstall)
        cmd_uninstall
        ;;
    help|--help|-h)
        show_usage
        ;;
    *)
        echo "Error: Unknown command '${1:-}'"
        echo ""
        show_usage
        exit 1
        ;;
esac

