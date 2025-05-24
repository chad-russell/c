#!/usr/bin/env python3
"""
Home Cluster Deployment Preparation Tool

A robust Python script for preparing NixOS configurations and generating
deployment commands for home cluster nodes using nixos-anywhere with 
proper secrets management.

This tool prepares the required extra files and generates copy-paste ready
nixos-anywhere commands, allowing you to maintain full control over the
deployment process while automating the preparation steps.
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
                "[bold blue]🚀 Home Cluster Deployment Preparation Tool[/bold blue]\n"
                "[dim]Preparing NixOS configurations with SeaweedFS & HA[/dim]",
                border_style="blue"
            )
            self.console.print(banner)
        else:
            print("🚀 Home Cluster Deployment Preparation Tool")
            print("Preparing NixOS configurations with SeaweedFS & HA")
    
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
        
        # Create temporary directory with a predictable name for easier cleanup
        temp_dir = Path(tempfile.mkdtemp(prefix="nixos-anywhere-extra-"))
        
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
    
    def generate_deployment_commands(self, node_names: List[str], extra_files_dir: Path) -> List[str]:
        """Generate nixos-anywhere commands for the specified nodes."""
        commands = []
        
        for node_name in node_names:
            if node_name not in self.nodes:
                self.logger.warning(f"Unknown node: {node_name}, skipping...")
                continue
                
            node = self.nodes[node_name]
            cmd = [
                "nixos-anywhere",
                "--flake", f".#{node_name}",
                "--extra-files", str(extra_files_dir),
                "--chown", "/home/crussell/.ssh 1000:100",
                f"root@{node.ip}"
            ]
            commands.append(" ".join(cmd))
        
        return commands
    
    def print_deployment_guide(self, node_names: List[str], extra_files_dir: Path):
        """Print deployment commands and cleanup instructions."""
        commands = self.generate_deployment_commands(node_names, extra_files_dir)
        
        if self.console:
            # Print deployment commands
            self.console.print("\n[bold green]🚀 Deployment Commands[/bold green]")
            self.console.print("[dim]Copy and paste these commands to deploy:[/dim]\n")
            
            for i, cmd in enumerate(commands, 1):
                self.console.print(f"[bold cyan]# Deploy node {node_names[i-1]}[/bold cyan]")
                self.console.print(f"[yellow]{cmd}[/yellow]\n")
            
            # Print cleanup command
            self.console.print("[bold red]🧹 Cleanup Command[/bold red]")
            self.console.print("[dim]Run this when all deployments are complete:[/dim]\n")
            self.console.print(f"[red]rm -rf {extra_files_dir}[/red]\n")
            
            # Print helpful info
            self.console.print("[bold blue]ℹ️  Additional Information[/bold blue]")
            self.console.print(f"[dim]Virtual IP:[/dim] [cyan]{self.vip}[/cyan]")
            self.console.print(f"[dim]SSH after deployment:[/dim] [cyan]ssh crussell@<node-ip>[/cyan] or [cyan]ssh crussell@{self.vip}[/cyan]")
            self.console.print(f"[dim]Extra files directory:[/dim] [yellow]{extra_files_dir}[/yellow]")
            
        else:
            print("\n🚀 Deployment Commands")
            print("Copy and paste these commands to deploy:\n")
            
            for i, cmd in enumerate(commands, 1):
                print(f"# Deploy node {node_names[i-1]}")
                print(cmd)
                print()
            
            print("🧹 Cleanup Command")
            print("Run this when all deployments are complete:")
            print(f"rm -rf {extra_files_dir}")
            print()
            
            print("ℹ️  Additional Information")
            print(f"Virtual IP: {self.vip}")
            print(f"SSH after deployment: ssh crussell@<node-ip> or ssh crussell@{self.vip}")
            print(f"Extra files directory: {extra_files_dir}")

    def deploy_nodes(self, node_names: List[str], interactive: bool = True):
        """Prepare deployment and print commands for multiple nodes."""
        # Extract SSH key once
        ssh_key = self.extract_ssh_key()
        
        # Prepare extra files once (reused for all nodes)
        extra_files_dir = self.prepare_extra_files(ssh_key)
        
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
        
        # Confirm preparation
        if interactive:
            if self.console:
                if not Confirm.ask(f"Prepare deployment for {len(node_names)} node(s)?"):
                    self.logger.info("Deployment preparation cancelled by user")
                    # Clean up the extra files directory
                    shutil.rmtree(extra_files_dir, ignore_errors=True)
                    return
            else:
                response = input(f"Prepare deployment for {len(node_names)} node(s)? [y/N]: ")
                if response.lower() not in ['y', 'yes']:
                    self.logger.info("Deployment preparation cancelled by user")
                    # Clean up the extra files directory
                    shutil.rmtree(extra_files_dir, ignore_errors=True)
                    return
        
        # Print the deployment guide
        self.print_deployment_guide(node_names, extra_files_dir)

def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Prepare NixOS deployment commands for home cluster nodes",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s                    # Prepare deployment for all nodes (interactive)
  %(prog)s c1                 # Prepare deployment only for c1
  %(prog)s c1 c2 c3          # Prepare deployment for specific nodes
  %(prog)s --all --yes       # Prepare deployment for all nodes (non-interactive)
  %(prog)s --check-only      # Only run prerequisite checks
  
This tool prepares the extra files and generates nixos-anywhere commands
for you to copy and paste. It does not execute the deployment directly.
        """
    )
    
    parser.add_argument(
        "nodes", 
        nargs="*", 
        choices=["c1", "c2", "c3", "c4"],
        help="Nodes to prepare deployment for (default: all nodes)"
    )
    
    parser.add_argument(
        "--all", 
        action="store_true",
        help="Prepare deployment for all nodes"
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
        
        # Prepare deployment
        deployer.deploy_nodes(nodes_to_deploy, interactive=not args.yes)
        return 0
        
    except DeploymentError as e:
        deployer.logger.error(f"Deployment preparation failed: {e}")
        return 1
    except KeyboardInterrupt:
        deployer.logger.info("Deployment preparation cancelled by user")
        return 1
    except Exception as e:
        deployer.logger.error(f"Unexpected error: {e}")
        if args.verbose:
            import traceback
            traceback.print_exc()
        return 1

if __name__ == "__main__":
    sys.exit(main()) 