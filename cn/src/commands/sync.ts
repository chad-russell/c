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
import { createSSHConnection, hasFileDrift } from '../lib/ssh.ts';
import { serviceExists, getServiceFiles, validateService, getMainServiceName } from '../lib/services.ts';
import {
  listDeployedServices,
  ensureSystemdUserDir,
  removeServiceFiles,
  reloadSystemdDaemon,
  startService,
  stopAllRelatedServices,
  stopService,
} from '../lib/systemd.ts';
import { uploadFiles } from '../lib/ssh.ts';
import type { CommandOptions } from '../types.ts';
import type { NodeSSH } from 'node-ssh';
import { stdin as input, stdout as output } from 'process';
import * as readline from 'readline';

interface SyncPlan {
  toAdd: string[];
  toRemove: string[];
  toUpdate: string[];
  toKeep: string[];
}

/**
 * Calculate what needs to change (without drift detection)
 */
function calculateBasicSyncPlan(
  desiredServices: string[],
  deployedServices: string[]
): SyncPlan {
  const toAdd = desiredServices.filter(s => !deployedServices.includes(s));
  const toRemove = deployedServices.filter(s => !desiredServices.includes(s));
  const toKeep = desiredServices.filter(s => deployedServices.includes(s));
  
  return { toAdd, toRemove, toUpdate: [], toKeep };
}

/**
 * Detect drift for deployed services by comparing file checksums
 */
async function detectDrift(
  ssh: NodeSSH,
  services: string[],
  options?: { verbose?: boolean }
): Promise<string[]> {
  const servicesWithDrift: string[] = [];
  
  for (const serviceName of services) {
    const localFiles = getServiceFiles(serviceName);
    let hasDrift = false;
    
    for (const file of localFiles) {
      const remotePath = `.config/containers/systemd/${file.filename}`;
      const drift = await hasFileDrift(ssh, file.checksum, remotePath);
      
      if (drift) {
        if (options?.verbose) {
          console.log(chalk.gray(`    Drift detected: ${file.filename}`));
        }
        hasDrift = true;
        break; // One changed file is enough to mark service as drifted
      }
    }
    
    if (hasDrift) {
      servicesWithDrift.push(serviceName);
    }
  }
  
  return servicesWithDrift;
}

/**
 * Show the sync plan to the user
 */
function showPlan(plan: SyncPlan, machineName: string): void {
  const totalChanges = plan.toAdd.length + plan.toRemove.length + plan.toUpdate.length;
  
  if (totalChanges === 0) {
    console.log(chalk.green(`\n✓ ${machineName} is already in sync. No changes needed.\n`));
    return;
  }
  
  console.log(chalk.blue(`\n📋 Sync Plan for ${machineName}\n`));
  console.log(chalk.gray(`Plan: ${chalk.green(`${plan.toAdd.length} to add`)}, ${chalk.yellow(`${plan.toUpdate.length} to update`)}, ${chalk.red(`${plan.toRemove.length} to remove`)}, ${chalk.gray(`${plan.toKeep.length} unchanged`)}\n`));
  
  if (plan.toAdd.length > 0) {
    console.log(chalk.green('Services to add:'));
    for (const service of plan.toAdd) {
      console.log(chalk.green(`  + ${service}`));
    }
    console.log();
  }
  
  if (plan.toUpdate.length > 0) {
    console.log(chalk.yellow('Services to update (drift detected):'));
    for (const service of plan.toUpdate) {
      console.log(chalk.yellow(`  ~ ${service}`));
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
  
  if (plan.toKeep.length > 0 && (plan.toAdd.length > 0 || plan.toRemove.length > 0 || plan.toUpdate.length > 0)) {
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
  options: CommandOptions & { yes?: boolean; force?: boolean }
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
      if (options.force) {
        console.log(chalk.yellow(`  Force mode: all services will be updated\n`));
      }
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
      
      // Calculate basic sync plan
      const plan = calculateBasicSyncPlan(
        options.service ? desiredServices : machineConfig.services,
        deployedServices
      );
      
      // Detect drift for services that are already deployed
      // (unless --force is used, which treats all as needing update)
      if (options.force && plan.toKeep.length > 0) {
        // Force mode: treat all existing services as needing update
        plan.toUpdate = [...plan.toKeep];
        plan.toKeep = [];
        if (options.verbose) {
          console.log(chalk.yellow(`  Force mode: marking ${plan.toUpdate.length} service(s) for update\n`));
        }
      } else if (plan.toKeep.length > 0) {
        // Normal mode: detect drift
        if (options.verbose) {
          console.log(chalk.gray(`  Checking for drift in ${plan.toKeep.length} deployed service(s)...\n`));
        }
        const driftedServices = await detectDrift(ssh, plan.toKeep, { verbose: options.verbose });
        plan.toUpdate = driftedServices;
        plan.toKeep = plan.toKeep.filter(s => !driftedServices.includes(s));
      }
      
      // Show the plan
      showPlan(plan, machineName);
      
      // If no changes, exit early
      if (plan.toAdd.length === 0 && plan.toRemove.length === 0 && plan.toUpdate.length === 0) {
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
      
      // Stop services that need updating (before uploading new files)
      if (plan.toUpdate.length > 0) {
        console.log(chalk.yellow(`Stopping ${plan.toUpdate.length} service(s) for update...\n`));
        
        for (const serviceName of plan.toUpdate) {
          const mainServiceName = getMainServiceName(serviceName);
          console.log(chalk.gray(`  Stopping ${mainServiceName}...`));
          
          try {
            await stopService(ssh, mainServiceName, { verbose: options.verbose });
            console.log(chalk.green(`    ✓ Stopped\n`));
          } catch (error) {
            if (error instanceof Error) {
              console.log(chalk.yellow(`    ⚠ Warning: ${error.message}\n`));
            }
          }
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
      
      // Update services with drift
      if (plan.toUpdate.length > 0) {
        await ensureSystemdUserDir(ssh, { verbose: options.verbose });
        
        console.log(chalk.yellow(`Updating ${plan.toUpdate.length} service(s)...\n`));
        
        for (const serviceName of plan.toUpdate) {
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
      if (plan.toAdd.length > 0 || plan.toRemove.length > 0 || plan.toUpdate.length > 0) {
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
      
      // Restart updated services
      if (plan.toUpdate.length > 0) {
        console.log(chalk.blue('Restarting updated services...\n'));
        
        for (const serviceName of plan.toUpdate) {
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
      if (plan.toUpdate.length > 0) summary.push(chalk.yellow(`${plan.toUpdate.length} updated`));
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

