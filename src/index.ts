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

const program = new Command();

program
  .name('homelab')
  .description('Declarative deployment system for Podman Quadlet services')
  .version('0.1.0');

// Deploy command
program
  .command('deploy')
  .description('Deploy services to a machine')
  .argument('<machine>', 'target machine name from machines.yaml')
  .option('-d, --dry-run', 'show what would be deployed without making changes')
  .option('-s, --service <name>', 'deploy only a specific service')
  .option('-v, --verbose', 'show detailed output')
  .action(deployCommand);

// Status command
program
  .command('status')
  .description('Check deployment status on a machine')
  .argument('<machine>', 'target machine name from machines.yaml')
  .option('-v, --verbose', 'show detailed output')
  .action(async (machine: string, options) => {
    console.log(chalk.blue('📊 Status command'));
    console.log(chalk.gray(`Machine: ${machine}`));
    
    // TODO: Implement status logic
    console.log(chalk.yellow('\n⚠️  Status command not yet implemented'));
  });

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

// Parse command line arguments
program.parse();

