#!/usr/bin/env bash

# Homelab Cluster Deployment Script
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# Check if sops key exists
check_sops_key() {
    if [[ ! -f "$HOME/.config/sops/age/keys.txt" ]]; then
        error "SOPS age key not found at $HOME/.config/sops/age/keys.txt"
    fi
    log "SOPS age key found"
}

# Check if secrets are encrypted
check_secrets() {
    if ! grep -q "sops:" secrets/secrets.yaml; then
        error "secrets/secrets.yaml is not encrypted with sops. Run: sops -e -i secrets/secrets.yaml"
    fi
    log "Secrets file is encrypted"
}

# Check if SSH key exists for initial access
check_ssh_key() {
    if [[ ! -f "$HOME/.ssh/id_rsa" ]] && [[ ! -f "$HOME/.ssh/id_ed25519" ]]; then
        error "No SSH key found. Need SSH key for initial root access to target machines."
    fi
    log "SSH key found for deployment"
}

# Decrypt and extract SSH public key from secrets
extract_ssh_key() {
    local temp_secrets=$(mktemp)
    trap "rm -f $temp_secrets" EXIT
    
    # Decrypt secrets to temporary file
    sops -d secrets/secrets.yaml > "$temp_secrets" || error "Failed to decrypt secrets"
    
    # Extract SSH key (assuming it's in YAML format)
    local ssh_key=$(grep -A5 "crussell:" "$temp_secrets" | tail -n +2 | sed 's/^[[:space:]]*//' | tr -d '\n')
    
    if [[ -z "$ssh_key" ]]; then
        error "Could not extract SSH key from secrets"
    fi
    
    echo "$ssh_key"
}

# Deploy to a single node
deploy_node() {
    local node="$1"
    local ip="192.168.68.7$((${node#c} + 0))"  # c1->71, c2->72, etc.
    
    log "Deploying to $node ($ip)..."
    
    # Create temporary directory for extra files
    local temp_dir=$(mktemp -d)
    trap "rm -rf $temp_dir" EXIT
    
    # Set up SOPS age key with proper permissions (following nixos-anywhere docs pattern)
    install -d -m755 "$temp_dir/etc/sops/age"
    cp "$HOME/.config/sops/age/keys.txt" "$temp_dir/etc/sops/age/"
    chmod 600 "$temp_dir/etc/sops/age/keys.txt"
    
    # Set up SSH key for the crussell user (extract from encrypted secrets)
    local ssh_key=$(extract_ssh_key)
    install -d -m755 "$temp_dir/home/crussell/.ssh"
    echo "$ssh_key" > "$temp_dir/home/crussell/.ssh/authorized_keys"
    chmod 600 "$temp_dir/home/crussell/.ssh/authorized_keys"
    
    # Deploy with nixos-anywhere
    nixos-anywhere \
        --flake ".#$node" \
        --extra-files "$temp_dir" \
        --chown "/home/crussell/.ssh 1000:100" \
        --build-on-remote \
        "root@$ip" || error "Failed to deploy to $node"
    
    log "Successfully deployed to $node"
}

# Main deployment function
main() {
    log "Starting homelab cluster deployment"
    
    # Pre-deployment checks
    check_sops_key
    check_secrets
    check_ssh_key
    
    # Check if flake builds
    log "Checking flake validity..."
    nix flake check || error "Flake check failed"
    
    if [[ $# -eq 0 ]]; then
        # Deploy to all nodes
        for node in c1 c2 c3 c4; do
            deploy_node "$node"
        done
    else
        # Deploy to specific nodes
        for node in "$@"; do
            if [[ ! "$node" =~ ^c[1-4]$ ]]; then
                error "Invalid node: $node. Must be c1, c2, c3, or c4"
            fi
            deploy_node "$node"
        done
    fi
    
    log "Deployment completed successfully!"
    log "Virtual IP: 192.168.68.70"
    log "Individual nodes: c1=192.168.68.71, c2=192.168.68.72, c3=192.168.68.73, c4=192.168.68.74"
    log ""
    log "You can now SSH to any node using: ssh crussell@192.168.68.7X"
    log "Or use the VIP: ssh crussell@192.168.68.70"
}

# Help function
show_help() {
    cat << EOF
Homelab Cluster Deployment Script

Usage: $0 [node1] [node2] ...

Examples:
    $0          # Deploy to all nodes (c1, c2, c3, c4)
    $0 c1       # Deploy only to c1
    $0 c1 c3    # Deploy to c1 and c3

Prerequisites:
    1. SOPS age key at ~/.config/sops/age/keys.txt
    2. Encrypted secrets at secrets/secrets.yaml
    3. SSH key pair for initial root access
    4. nixos-anywhere installed
    5. Root SSH access to target machines

Setup Steps:
    1. Generate age key: age-keygen -o ~/.config/sops/age/keys.txt
    2. Add your SSH public key to secrets/secrets.yaml
    3. Encrypt secrets: sops -e -i secrets/secrets.yaml
    4. Ensure root SSH access to target machines
    5. Run deployment script

EOF
}

# Parse command line arguments
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac 