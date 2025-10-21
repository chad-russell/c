/**
 * Deploy command - Deploy services to a machine
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
} from '../lib/systemd.ts';
import { uploadFiles } from '../lib/ssh.ts';
import type { CommandOptions } from '../types.ts';

export async function deployCommand(
  machineName: string,
  options: CommandOptions
): Promise<void> {
  try {
    console.log(chalk.blue(`\n🚀 Deploying to ${machineName}\n`));
    
    // Load machine configuration
    const machineConfig = getMachineConfig(machineName);
    
    if (options.verbose) {
      console.log(chalk.gray(`  Host: ${machineConfig.hostname}`));
      console.log(chalk.gray(`  User: ${machineConfig.user}\n`));
    }
    
    // Determine which services to deploy
    const servicesToDeploy = options.service 
      ? [options.service]
      : machineConfig.services;
    
    if (servicesToDeploy.length === 0) {
      console.log(chalk.yellow('⚠️  No services configured for this machine\n'));
      return;
    }
    
    // Validate all services exist locally
    for (const serviceName of servicesToDeploy) {
      if (!serviceExists(serviceName)) {
        throw new Error(`Service "${serviceName}" not found in services/ directory`);
      }
      
      const validation = validateService(serviceName);
      if (!validation.valid) {
        throw new Error(`Service "${serviceName}" is invalid: ${validation.error}`);
      }
    }
    
    if (options.dryRun) {
      console.log(chalk.yellow('  🏃 Dry-run mode: showing what would be deployed\n'));
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
      
      if (options.verbose && deployedServices.length > 0) {
        console.log(chalk.gray(`  Currently deployed: ${deployedServices.join(', ')}\n`));
      }
      
      // Calculate what needs to be removed
      const servicesToRemove = deployedServices.filter(
        s => !machineConfig.services.includes(s)
      );
      
      // Remove services that shouldn't be there (unless deploying specific service)
      if (!options.service && servicesToRemove.length > 0) {
        console.log(chalk.yellow(`  🗑️  Removing ${servicesToRemove.length} service(s)...`));
        
        for (const serviceName of servicesToRemove) {
          if (options.dryRun) {
            console.log(chalk.gray(`    Would remove: ${serviceName}`));
          } else {
            console.log(chalk.gray(`    Removing ${serviceName}...`));
            await removeServiceFiles(ssh, serviceName, { verbose: options.verbose });
            console.log(chalk.green(`    ✓ Removed ${serviceName}`));
          }
        }
        console.log();
      }
      
      // Ensure systemd directory exists
      if (!options.dryRun) {
        await ensureSystemdUserDir(ssh, { verbose: options.verbose });
      }
      
      // Deploy each service
      console.log(chalk.blue(`  📦 Deploying ${servicesToDeploy.length} service(s)...\n`));
      
      for (const serviceName of servicesToDeploy) {
        console.log(chalk.cyan(`  ${serviceName}`));
        
        // Get service files
        const files = getServiceFiles(serviceName);
        console.log(chalk.gray(`    ${files.length} file(s) to deploy`));
        
        if (options.dryRun) {
          for (const file of files) {
            console.log(chalk.gray(`      - ${file.filename}`));
          }
        } else {
          // Upload files
          const filesToUpload = files.map(f => ({
            local: f.path,
            remote: `.config/containers/systemd/${f.filename}`,
          }));
          
          await uploadFiles(ssh, filesToUpload, { verbose: options.verbose });
          console.log(chalk.green(`    ✓ Uploaded files`));
        }
      }
      
      if (!options.dryRun) {
        // Reload systemd daemon
        console.log(chalk.gray(`\n  Reloading systemd daemon...`));
        await reloadSystemdDaemon(ssh, { verbose: options.verbose });
        console.log(chalk.green('  ✓ Daemon reloaded\n'));
        
        // Start and enable services
        console.log(chalk.blue('  🎬 Starting services...\n'));
        
        for (const serviceName of servicesToDeploy) {
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
        
        console.log(chalk.green.bold('✅ Deployment complete!\n'));
      } else {
        console.log(chalk.yellow('\n  Dry-run complete. No changes were made.\n'));
      }
      
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

