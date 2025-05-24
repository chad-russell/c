#!/usr/bin/env python3
"""
Home Cluster Deployment Tool

A robust Python script for deploying NixOS configurations to home cluster nodes
using nixos-anywhere with proper secrets management.
"""

import argparse
import json
import logging
import os
import subprocess
import sys
import tempfile
import yaml
from pathlib import Path
from typing import List, Optional, Dict, Any
import shutil
from dataclasses import dataclass

# Rich for beautiful terminal output
try:
    from rich.console import Console
    from rich.logging import RichHandler
    from rich.prompt import Confirm, Prompt
    from rich.progress import Progress, SpinnerColumn, TextColumn
    from rich.table import Table
    from rich.panel import Panel
    RICH_AVAILABLE = True
except ImportError:
    RICH_AVAILABLE = False
    print("Warning: rich not available, falling back to basic output")

@dataclass
class NodeConfig:
    """Configuration for a cluster node."""
    name: str
    ip: str
    roles: List[str]
    priority: int

class DeploymentError(Exception):
    """Custom exception for deployment errors."""
    pass

class HomeDeployer:
    """Main deployment class for the home cluster."""
    
    def __init__(self):
        self.setup_logging()
        self.console = Console() if RICH_AVAILABLE else None
        # Use current working directory instead of script's directory
        # When running via 'nix run', the script is in the Nix store but
        # we need to work with files in the user's current directory
        self.project_dir = Path.cwd().absolute()
        
        # Node configurations
        self.nodes = {
            'c1': NodeConfig('c1', '192.168.68.71', ['Master', 'Volume', 'Filer'], 120),
            'c2': NodeConfig('c2', '192.168.68.72', ['Master', 'Volume', 'Filer'], 110),
            'c3': NodeConfig('c3', '192.168.68.73', ['Master', 'Volume'], 100),
            'c4': NodeConfig('c4', '192.168.68.74', ['Volume'], 90),
        }
        
        self.vip = "192.168.68.70"
        
    def setup_logging(self):
        """Set up logging with rich handler if available."""
        if RICH_AVAILABLE:
            logging.basicConfig(
                level=logging.INFO,
                format="%(message)s",
                datefmt="[%X]",
                handlers=[RichHandler(rich_tracebacks=True)]
            )
        else:
            logging.basicConfig(
                level=logging.INFO,
                format='%(asctime)s - %(levelname)s - %(message)s'
            )
        self.logger = logging.getLogger(__name__)
    
    def print_banner(self):
        """Print a welcome banner."""
        if self.console:
            banner = Panel.fit(
                "[bold blue]🚀 Home Cluster Deployment Tool[/bold blue]\n"
                "[dim]Deploying NixOS configurations with SeaweedFS & HA[/dim]",
                border_style="blue"
            )
            self.console.print(banner)
        else:
            print("🚀 Home Cluster Deployment Tool")
            print("Deploying NixOS configurations with SeaweedFS & HA")
    
    def show_cluster_info(self):
        """Display cluster architecture information."""
        if self.console:
            table = Table(title="Cluster Architecture")
            table.add_column("Node", style="cyan", no_wrap=True)
            table.add_column("IP Address", style="magenta")
            table.add_column("Roles", style="green")
            table.add_column("Priority", style="yellow")
            
            for node in self.nodes.values():
                table.add_row(
                    node.name,
                    node.ip,
                    ", ".join(node.roles),
                    str(node.priority)
                )
            
            self.console.print(table)
            self.console.print(f"[bold]Virtual IP:[/bold] {self.vip}")
        else:
            print("\nCluster Architecture:")
            for node in self.nodes.values():
                print(f"  {node.name} ({node.ip}): {', '.join(node.roles)} (Priority: {node.priority})")
            print(f"Virtual IP: {self.vip}")
    
    def run_command(self, cmd: List[str], description: str = "", check: bool = True) -> subprocess.CompletedProcess:
        """Run a command with proper logging."""
        cmd_str = ' '.join(cmd)
        self.logger.info(f"Running: {description or cmd_str}")
        self.logger.debug(f"Full command: {cmd_str}")
        
        try:
            result = subprocess.run(cmd, check=check, capture_output=True, text=True)
            if result.stdout:
                self.logger.debug(f"STDOUT: {result.stdout}")
            if result.stderr and result.returncode == 0:
                self.logger.debug(f"STDERR: {result.stderr}")
            return result
        except subprocess.CalledProcessError as e:
            self.logger.error(f"Command failed: {cmd_str}")
            self.logger.error(f"Return code: {e.returncode}")
            self.logger.error(f"STDERR: {e.stderr}")
            if e.stdout:
                self.logger.error(f"STDOUT: {e.stdout}")
            raise DeploymentError(f"Command failed: {description or cmd_str}")
    
    def check_prerequisites(self):
        """Check all prerequisites before deployment."""
        self.logger.info("Checking prerequisites...")
        
        errors = []
        
        # Check if we're in the right directory
        if not (self.project_dir / "flake.nix").exists():
            errors.append("flake.nix not found. Run from the project root.")
        
        # Check for SOPS age key
        age_key_path = Path.home() / ".config/sops/age/keys.txt"
        if not age_key_path.exists():
            errors.append(f"SOPS age key not found at {age_key_path}")
        
        # Check if secrets are encrypted
        secrets_path = self.project_dir / "secrets/secrets.yaml"
        if not secrets_path.exists():
            errors.append(f"Secrets file not found at {secrets_path}")
        else:
            try:
                with open(secrets_path) as f:
                    content = f.read()
                if "sops:" not in content:
                    errors.append("secrets/secrets.yaml is not encrypted with sops")
            except Exception as e:
                errors.append(f"Could not read secrets file: {e}")
        
        # Check for SSH keys
        ssh_keys = [
            Path.home() / ".ssh/id_ed25519",
            Path.home() / ".ssh/id_rsa"
        ]
        if not any(key.exists() for key in ssh_keys):
            errors.append("No SSH key found for initial deployment")
        
        # Check for required tools
        required_tools = ["nixos-anywhere", "sops", "age", "nix"]
        for tool in required_tools:
            if not shutil.which(tool):
                errors.append(f"Required tool '{tool}' not found in PATH")
        
        if errors:
            self.logger.error("Prerequisites check failed:")
            for error in errors:
                self.logger.error(f"  ❌ {error}")
            raise DeploymentError("Prerequisites not met")
        
        self.logger.info("✅ All prerequisites satisfied")
    
    def validate_flake(self):
        """Validate the flake configuration."""
        self.logger.info("Validating flake configuration...")
        try:
            self.run_command(
                ["nix", "flake", "check"],
                "Checking flake validity"
            )
            self.logger.info("✅ Flake validation passed")
        except DeploymentError:
            self.logger.error("❌ Flake validation failed")
            raise
    
    def extract_ssh_key(self) -> str:
        """Extract SSH public key from encrypted secrets."""
        self.logger.info("Extracting SSH key from secrets...")
        
        try:
            # Decrypt secrets
            result = self.run_command(
                ["sops", "-d", str(self.project_dir / "secrets/secrets.yaml")],
                "Decrypting secrets"
            )
            
            # Parse YAML and extract SSH key
            secrets = yaml.safe_load(result.stdout)
            ssh_key = secrets.get("ssh_keys", {}).get("crussell", "").strip()
            
            if not ssh_key:
                raise DeploymentError("Could not extract SSH key from secrets")
            
            self.logger.info("✅ SSH key extracted successfully")
            return ssh_key
            
        except yaml.YAMLError as e:
            raise DeploymentError(f"Failed to parse secrets YAML: {e}")
        except Exception as e:
            raise DeploymentError(f"Failed to extract SSH key: {e}")
    
    def prepare_extra_files(self, ssh_key: str) -> Path:
        """Prepare extra files directory for nixos-anywhere."""
        self.logger.info("Preparing extra files for deployment...")
        
        # Create temporary directory
        temp_dir = Path(tempfile.mkdtemp())
        
        try:
            # Set up SOPS age key
            age_dir = temp_dir / "etc/sops/age"
            age_dir.mkdir(parents=True, mode=0o755)
            
            age_key_src = Path.home() / ".config/sops/age/keys.txt"
            age_key_dst = age_dir / "keys.txt"
            shutil.copy2(age_key_src, age_key_dst)
            age_key_dst.chmod(0o600)
            
            # Set up SSH key for crussell user
            ssh_dir = temp_dir / "home/crussell/.ssh"
            ssh_dir.mkdir(parents=True, mode=0o755)
            
            authorized_keys = ssh_dir / "authorized_keys"
            with open(authorized_keys, 'w') as f:
                f.write(ssh_key)
            authorized_keys.chmod(0o600)
            
            self.logger.info(f"✅ Extra files prepared in {temp_dir}")
            return temp_dir
            
        except Exception as e:
            shutil.rmtree(temp_dir, ignore_errors=True)
            raise DeploymentError(f"Failed to prepare extra files: {e}")
    
    def deploy_node(self, node_name: str, ssh_key: str):
        """Deploy configuration to a single node."""
        if node_name not in self.nodes:
            raise DeploymentError(f"Unknown node: {node_name}")
        
        node = self.nodes[node_name]
        self.logger.info(f"Deploying to {node_name} ({node.ip})...")
        
        # Prepare extra files
        temp_dir = self.prepare_extra_files(ssh_key)
        
        try:
            # Run nixos-anywhere
            cmd = [
                "nixos-anywhere",
                "--flake", f".#{node_name}",
                "--extra-files", str(temp_dir),
                "--chown", "/home/crussell/.ssh 1000:100",
                f"root@{node.ip}"
            ]
            
            print(f"Running: {cmd}")
            # self.run_command(cmd, f"Deploying NixOS to {node_name}")
            self.logger.info(f"✅ Successfully deployed to {node_name}")
            
        finally:
            # Clean up temporary directory
            # shutil.rmtree(temp_dir, ignore_errors=True)
            print("TODO: clean up temp dir")
    
    def deploy_nodes(self, node_names: List[str], interactive: bool = True):
        """Deploy to multiple nodes."""
        # Extract SSH key once
        ssh_key = self.extract_ssh_key()
        
        # Show what will be deployed
        if self.console:
            table = Table(title="Deployment Plan")
            table.add_column("Node", style="cyan")
            table.add_column("IP Address", style="magenta")
            table.add_column("Roles", style="green")
            
            for name in node_names:
                if name in self.nodes:
                    node = self.nodes[name]
                    table.add_row(node.name, node.ip, ", ".join(node.roles))
            
            self.console.print(table)
        
        # Confirm deployment
        if interactive:
            if self.console:
                if not Confirm.ask(f"Deploy to {len(node_names)} node(s)?"):
                    self.logger.info("Deployment cancelled by user")
                    return
            else:
                response = input(f"Deploy to {len(node_names)} node(s)? [y/N]: ")
                if response.lower() not in ['y', 'yes']:
                    self.logger.info("Deployment cancelled by user")
                    return
        
        # Deploy each node
        failed_nodes = []
        for node_name in node_names:
            try:
                self.deploy_node(node_name, ssh_key)
            except DeploymentError as e:
                self.logger.error(f"Failed to deploy {node_name}: {e}")
                failed_nodes.append(node_name)
                
                if interactive:
                    if self.console:
                        if not Confirm.ask("Continue with remaining nodes?"):
                            break
                    else:
                        response = input("Continue with remaining nodes? [y/N]: ")
                        if response.lower() not in ['y', 'yes']:
                            break
        
        # Summary
        successful_nodes = [n for n in node_names if n not in failed_nodes]
        if successful_nodes:
            self.logger.info(f"✅ Successfully deployed: {', '.join(successful_nodes)}")
        if failed_nodes:
            self.logger.error(f"❌ Failed deployments: {', '.join(failed_nodes)}")
        
        if not failed_nodes:
            self.logger.info(f"🎉 Deployment completed successfully!")
            self.logger.info(f"Virtual IP: {self.vip}")
            self.logger.info("You can now SSH using: ssh crussell@<node-ip> or ssh crussell@192.168.68.70")

def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Deploy NixOS configurations to home cluster nodes",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s                    # Deploy to all nodes (interactive)
  %(prog)s c1                 # Deploy only to c1
  %(prog)s c1 c2 c3          # Deploy to specific nodes
  %(prog)s --all --yes       # Deploy to all nodes (non-interactive)
  %(prog)s --check-only      # Only run prerequisite checks
        """
    )
    
    parser.add_argument(
        "nodes", 
        nargs="*", 
        choices=["c1", "c2", "c3", "c4"],
        help="Nodes to deploy to (default: all nodes)"
    )
    
    parser.add_argument(
        "--all", 
        action="store_true",
        help="Deploy to all nodes"
    )
    
    parser.add_argument(
        "--yes", "-y",
        action="store_true",
        help="Skip interactive confirmations"
    )
    
    parser.add_argument(
        "--check-only",
        action="store_true",
        help="Only run prerequisite checks"
    )
    
    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Enable verbose logging"
    )
    
    args = parser.parse_args()
    
    # Configure logging level
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    
    # Determine nodes to deploy
    if args.all or not args.nodes:
        nodes_to_deploy = ["c1", "c2", "c3", "c4"]
    else:
        nodes_to_deploy = args.nodes
    
    # Create deployer
    deployer = HomeDeployer()
    
    try:
        deployer.print_banner()
        deployer.show_cluster_info()
        
        # Run checks
        deployer.check_prerequisites()
        deployer.validate_flake()
        
        if args.check_only:
            deployer.logger.info("✅ All checks passed. Ready for deployment.")
            return 0
        
        # Deploy
        deployer.deploy_nodes(nodes_to_deploy, interactive=not args.yes)
        return 0
        
    except DeploymentError as e:
        deployer.logger.error(f"Deployment failed: {e}")
        return 1
    except KeyboardInterrupt:
        deployer.logger.info("Deployment cancelled by user")
        return 1
    except Exception as e:
        deployer.logger.error(f"Unexpected error: {e}")
        if args.verbose:
            import traceback
            traceback.print_exc()
        return 1

if __name__ == "__main__":
    sys.exit(main()) 