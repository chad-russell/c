#!/usr/bin/env bun

/**
 * Homelab Deployment CLI
 * 
 * Declarative deployment system for managing Podman Quadlet services
 * across multiple homelab machines using SSH and systemd.
 */

import { Command } from 'commander';
import chalk from 'chalk';
import { listCommand } from './commands/list.ts';
import { deployCommand } from './commands/deploy.ts';
import { syncCommand } from './commands/sync.ts';
import { logsCommand } from './commands/logs.ts';
import { statusCommand } from './commands/status.ts';

const program = new Command();

program
  .name('homelab')
  .description('Declarative deployment system for Podman Quadlet services')
  .version('0.1.0');

// Sync command (main command - Terraform-style)
program
  .command('sync')
  .description('Sync machine state with configuration (shows plan and asks for confirmation)')
  .argument('<machine>', 'target machine name from machines.yaml')
  .option('-y, --yes', 'skip confirmation prompt and apply changes immediately')
  .option('-f, --force', 'force re-upload of all services (skip drift detection)')
  .option('-d, --dry-run', 'show plan without making any changes')
  .option('-s, --service <name>', 'sync only a specific service')
  .option('-v, --verbose', 'show detailed output')
  .action(syncCommand);

// Deploy command (kept for backwards compatibility)
program
  .command('deploy')
  .description('Deploy services to a machine (legacy - use sync instead)')
  .argument('<machine>', 'target machine name from machines.yaml')
  .option('-d, --dry-run', 'show what would be deployed without making changes')
  .option('-s, --service <name>', 'deploy only a specific service')
  .option('-v, --verbose', 'show detailed output')
  .action(deployCommand);

// Status command
program
  .command('status')
  .description('Check deployment status with metrics and drift detection')
  .argument('<machine>', 'target machine name from machines.yaml')
  .option('-v, --verbose', 'show detailed output')
  .option('-m, --metrics', 'show container metrics (CPU, memory, network)')
  .action(statusCommand);

// Undeploy command
program
  .command('undeploy')
  .description('Remove services from a machine')
  .argument('<machine>', 'target machine name from machines.yaml')
  .option('-s, --service <name>', 'remove only a specific service')
  .option('-v, --verbose', 'show detailed output')
  .action(async (machine: string, options) => {
    console.log(chalk.red('🗑️  Undeploy command'));
    console.log(chalk.gray(`Machine: ${machine}`));
    if (options.service) console.log(chalk.gray(`Service: ${options.service}`));
    
    // TODO: Implement undeploy logic
    console.log(chalk.yellow('\n⚠️  Undeploy command not yet implemented'));
  });

// List command (helpful for showing available machines)
program
  .command('list')
  .description('List all configured machines')
  .action(listCommand);

// Logs command
program
  .command('logs')
  .description('Fetch logs from remote services')
  .option('-m, --machine <name>', 'show logs from a specific machine')
  .option('-s, --service <name>', 'show logs for a specific service (auto-discovers machine)')
  .option('-f, --follow', 'follow logs in real-time')
  .option('--since <time>', 'show logs since timestamp (e.g., "1 hour ago", "2024-01-01")')
  .option('--until <time>', 'show logs until timestamp')
  .option('-n, --lines <number>', 'number of lines to show', (val) => parseInt(val, 10), 50)
  .option('-v, --verbose', 'show detailed output')
  .action(logsCommand);

// Parse command line arguments
program.parse();

