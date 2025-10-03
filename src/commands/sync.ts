/**
 * Sync command - Synchronize machine state with configuration
 * 
 * Similar to Terraform, this command:
 * 1. Calculates what needs to change (plan)
 * 2. Shows the changes to the user
 * 3. Asks for confirmation (unless --yes)
 * 4. Applies the changes
 */

import chalk from 'chalk';
import { getMachineConfig } from '../lib/config.ts';
import { createSSHConnection } from '../lib/ssh.ts';
import { serviceExists, getServiceFiles, validateService, getMainServiceName } from '../lib/services.ts';
import {
  listDeployedServices,
  ensureSystemdUserDir,
  removeServiceFiles,
  reloadSystemdDaemon,
  startService,
  stopAllRelatedServices,
} from '../lib/systemd.ts';
import { uploadFiles } from '../lib/ssh.ts';
import type { CommandOptions } from '../types.ts';
import { stdin as input, stdout as output } from 'process';
import * as readline from 'readline';

interface SyncPlan {
  toAdd: string[];
  toRemove: string[];
  toKeep: string[];
}

/**
 * Calculate what needs to change
 */
function calculateSyncPlan(
  desiredServices: string[],
  deployedServices: string[]
): SyncPlan {
  const toAdd = desiredServices.filter(s => !deployedServices.includes(s));
  const toRemove = deployedServices.filter(s => !desiredServices.includes(s));
  const toKeep = desiredServices.filter(s => deployedServices.includes(s));
  
  return { toAdd, toRemove, toKeep };
}

/**
 * Show the sync plan to the user
 */
function showPlan(plan: SyncPlan, machineName: string): void {
  const totalChanges = plan.toAdd.length + plan.toRemove.length;
  
  if (totalChanges === 0) {
    console.log(chalk.green(`\n✓ ${machineName} is already in sync. No changes needed.\n`));
    return;
  }
  
  console.log(chalk.blue(`\n📋 Sync Plan for ${machineName}\n`));
  console.log(chalk.gray(`Plan: ${chalk.green(`${plan.toAdd.length} to add`)}, ${chalk.red(`${plan.toRemove.length} to remove`)}, ${chalk.gray(`${plan.toKeep.length} unchanged`)}\n`));
  
  if (plan.toAdd.length > 0) {
    console.log(chalk.green('Services to add:'));
    for (const service of plan.toAdd) {
      console.log(chalk.green(`  + ${service}`));
    }
    console.log();
  }
  
  if (plan.toRemove.length > 0) {
    console.log(chalk.red('Services to remove:'));
    for (const service of plan.toRemove) {
      console.log(chalk.red(`  - ${service}`));
    }
    console.log();
  }
  
  if (plan.toKeep.length > 0 && (plan.toAdd.length > 0 || plan.toRemove.length > 0)) {
    console.log(chalk.gray('Services unchanged:'));
    for (const service of plan.toKeep) {
      console.log(chalk.gray(`    ${service}`));
    }
    console.log();
  }
}

/**
 * Ask user for confirmation
 */
async function askConfirmation(): Promise<boolean> {
  const rl = readline.createInterface({ input, output });
  
  return new Promise((resolve) => {
    rl.question(chalk.yellow('Apply these changes? (yes/no): '), (answer) => {
      rl.close();
      const normalized = answer.trim().toLowerCase();
      resolve(normalized === 'yes' || normalized === 'y');
    });
  });
}

export async function syncCommand(
  machineName: string,
  options: CommandOptions & { yes?: boolean }
): Promise<void> {
  try {
    console.log(chalk.blue(`\n🔄 Syncing ${machineName}\n`));
    
    // Load machine configuration
    const machineConfig = getMachineConfig(machineName);
    const desiredServices = options.service 
      ? [options.service]
      : machineConfig.services;
    
    if (options.verbose) {
      console.log(chalk.gray(`  Host: ${machineConfig.hostname}`));
      console.log(chalk.gray(`  User: ${machineConfig.user}`));
      console.log(chalk.gray(`  Desired services: ${desiredServices.join(', ') || '(none)'}\n`));
    }
    
    // Validate all desired services exist locally
    for (const serviceName of desiredServices) {
      if (!serviceExists(serviceName)) {
        throw new Error(`Service "${serviceName}" not found in services/ directory`);
      }
      
      const validation = validateService(serviceName);
      if (!validation.valid) {
        throw new Error(`Service "${serviceName}" is invalid: ${validation.error}`);
      }
    }
    
    // Connect to machine
    console.log(chalk.gray(`  Connecting to ${machineConfig.hostname}...`));
    const ssh = await createSSHConnection({
      host: machineConfig.hostname,
      username: machineConfig.user,
    });
    console.log(chalk.green('  ✓ Connected\n'));
    
    try {
      // Get currently deployed services
      const deployedServices = await listDeployedServices(ssh);
      
      // Calculate sync plan
      const plan = calculateSyncPlan(
        options.service ? desiredServices : machineConfig.services,
        deployedServices
      );
      
      // Show the plan
      showPlan(plan, machineName);
      
      // If no changes, exit early
      if (plan.toAdd.length === 0 && plan.toRemove.length === 0) {
        ssh.dispose();
        return;
      }
      
      // In dry-run mode, stop here
      if (options.dryRun) {
        console.log(chalk.yellow('Dry-run mode: no changes were made.\n'));
        ssh.dispose();
        return;
      }
      
      // Ask for confirmation unless --yes flag
      if (!options.yes) {
        const confirmed = await askConfirmation();
        if (!confirmed) {
          console.log(chalk.yellow('\n❌ Sync cancelled.\n'));
          ssh.dispose();
          return;
        }
        console.log();
      }
      
      // Apply changes
      console.log(chalk.blue('🚀 Applying changes...\n'));
      
      // Remove services first
      if (plan.toRemove.length > 0) {
        console.log(chalk.red(`Removing ${plan.toRemove.length} service(s)...\n`));
        
        for (const serviceName of plan.toRemove) {
          console.log(chalk.gray(`  Stopping all ${serviceName} services...`));
          const stoppedServices = await stopAllRelatedServices(ssh, serviceName, { verbose: options.verbose });
          
          if (stoppedServices.length > 0) {
            console.log(chalk.green(`    ✓ Stopped ${stoppedServices.length} service(s)`));
          } else {
            console.log(chalk.gray(`    (no running services found)`));
          }
          
          console.log(chalk.gray(`  Removing quadlet files...`));
          await removeServiceFiles(ssh, serviceName, { verbose: options.verbose });
          console.log(chalk.green(`  ✓ Removed ${serviceName}\n`));
        }
      }
      
      // Add new services
      if (plan.toAdd.length > 0) {
        await ensureSystemdUserDir(ssh, { verbose: options.verbose });
        
        console.log(chalk.green(`Adding ${plan.toAdd.length} service(s)...\n`));
        
        for (const serviceName of plan.toAdd) {
          console.log(chalk.cyan(`  ${serviceName}`));
          
          const files = getServiceFiles(serviceName);
          console.log(chalk.gray(`    Uploading ${files.length} file(s)...`));
          
          const filesToUpload = files.map(f => ({
            local: f.path,
            remote: `.config/containers/systemd/${f.filename}`,
          }));
          
          await uploadFiles(ssh, filesToUpload, { verbose: options.verbose });
          console.log(chalk.green(`    ✓ Uploaded\n`));
        }
      }
      
      // Reload systemd if we made any changes
      if (plan.toAdd.length > 0 || plan.toRemove.length > 0) {
        console.log(chalk.gray('Reloading systemd daemon...'));
        await reloadSystemdDaemon(ssh, { verbose: options.verbose });
        console.log(chalk.green('✓ Daemon reloaded\n'));
      }
      
      // Start new services
      if (plan.toAdd.length > 0) {
        console.log(chalk.blue('Starting new services...\n'));
        
        for (const serviceName of plan.toAdd) {
          const mainServiceName = getMainServiceName(serviceName);
          
          try {
            console.log(chalk.gray(`  Starting ${mainServiceName}...`));
            await startService(ssh, mainServiceName, { verbose: options.verbose });
            console.log(chalk.green(`  ✓ ${serviceName} is running\n`));
          } catch (error) {
            if (error instanceof Error) {
              console.error(chalk.red(`  ✗ Failed to start ${serviceName}: ${error.message}\n`));
            }
          }
        }
      }
      
      console.log(chalk.green.bold('✅ Sync complete!\n'));
      
      // Show summary
      const summary: string[] = [];
      if (plan.toAdd.length > 0) summary.push(chalk.green(`${plan.toAdd.length} added`));
      if (plan.toRemove.length > 0) summary.push(chalk.red(`${plan.toRemove.length} removed`));
      console.log(chalk.gray(`Summary: ${summary.join(', ')}\n`));
      
    } finally {
      ssh.dispose();
    }
    
  } catch (error) {
    if (error instanceof Error) {
      console.error(chalk.red(`\n❌ Error: ${error.message}\n`));
      process.exit(1);
    }
    throw error;
  }
}

