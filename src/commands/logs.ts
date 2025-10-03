/**
 * Logs command - Fetch logs from remote services
 */

import chalk from 'chalk';
import { getMachineConfig, listMachines, findMachineForService } from '../lib/config.ts';
import { createSSHConnection } from '../lib/ssh.ts';
import { getServiceLogs, listDeployedServices } from '../lib/systemd.ts';
import type { LogOptions } from '../types.ts';

interface LogCommandOptions extends LogOptions {
  machine?: string;
  service?: string;
}

export async function logsCommand(options: LogCommandOptions): Promise<void> {
  try {
    // Validate mutually exclusive flags
    if (options.machine && options.service) {
      console.log(chalk.red('❌ Error: --machine and --service flags are mutually exclusive'));
      console.log(chalk.gray('   Use --machine to show logs from a specific machine'));
      console.log(chalk.gray('   Use --service to auto-discover and show logs for a specific service'));
      process.exit(1);
    }
    
    // Case 1: Show logs for a specific service (auto-discover machine)
    if (options.service) {
      await showServiceLogs(options.service, options);
      return;
    }
    
    // Case 2: Show logs from a specific machine
    if (options.machine) {
      await showMachineLogs(options.machine, options);
      return;
    }
    
    // Case 3: Show logs from all machines and services
    await showAllLogs(options);
  } catch (error) {
    if (error instanceof Error) {
      console.log(chalk.red(`\n❌ Error: ${error.message}\n`));
    }
    process.exit(1);
  }
}

/**
 * Show logs for a specific service (auto-discover which machine it's on)
 */
async function showServiceLogs(
  serviceName: string,
  options: LogOptions
): Promise<void> {
  console.log(chalk.blue(`\n📋 Fetching logs for service: ${serviceName}\n`));
  
  // Find which machine(s) have this service
  const machines = findMachineForService(serviceName);
  
  if (machines.length === 0) {
    console.log(chalk.yellow(`⚠️  Service "${serviceName}" not found in any machine configuration`));
    process.exit(1);
  }
  
  if (machines.length > 1) {
    console.log(chalk.yellow(`⚠️  Service "${serviceName}" is configured on multiple machines:`));
    machines.forEach(m => console.log(chalk.gray(`   - ${m}`)));
    console.log(chalk.gray('\n   Please specify a machine using --machine flag'));
    process.exit(1);
  }
  
  const machineName = machines[0]!;
  
  if (options.verbose) {
    console.log(chalk.gray(`Auto-discovered machine: ${machineName}\n`));
  }
  
  // Connect and fetch logs
  const machineConfig = getMachineConfig(machineName);
  const ssh = await createSSHConnection({
    host: machineConfig.hostname,
    username: machineConfig.user,
  });
  
  try {
    if (options.follow) {
      console.log(chalk.blue(`Following logs from ${serviceName} on ${machineName}...\n`));
      console.log(chalk.gray('Press Ctrl+C to stop\n'));
    }
    
    await getServiceLogs(ssh, serviceName, options);
  } finally {
    ssh.dispose();
  }
}

/**
 * Show logs from all services on a specific machine
 */
async function showMachineLogs(
  machineName: string,
  options: LogOptions
): Promise<void> {
  console.log(chalk.blue(`\n📋 Fetching logs from machine: ${machineName}\n`));
  
  const machineConfig = getMachineConfig(machineName);
  const ssh = await createSSHConnection({
    host: machineConfig.hostname,
    username: machineConfig.user,
  });
  
  try {
    // Get list of deployed services
    const deployedServices = await listDeployedServices(ssh);
    
    if (deployedServices.length === 0) {
      console.log(chalk.yellow('⚠️  No services deployed on this machine'));
      return;
    }
    
    if (options.follow) {
      console.log(chalk.yellow('⚠️  Follow mode is only supported for a single service'));
      console.log(chalk.gray('   Use --service flag to follow a specific service\n'));
      process.exit(1);
    }
    
    if (options.verbose) {
      console.log(chalk.gray(`Found ${deployedServices.length} deployed service(s)\n`));
    }
    
    // Fetch logs from each service
    for (let i = 0; i < deployedServices.length; i++) {
      const service = deployedServices[i]!;
      
      if (i > 0) {
        console.log('\n' + chalk.gray('─'.repeat(80)) + '\n');
      }
      
      console.log(chalk.cyan(`[${machineName}:${service}]`));
      await getServiceLogs(ssh, service, { ...options, verbose: false });
    }
  } finally {
    ssh.dispose();
  }
}

/**
 * Show logs from all services on all machines
 */
async function showAllLogs(options: LogOptions): Promise<void> {
  console.log(chalk.blue('\n📋 Fetching logs from all machines\n'));
  
  if (options.follow) {
    console.log(chalk.yellow('⚠️  Follow mode is only supported for a single service'));
    console.log(chalk.gray('   Use --service flag to follow a specific service\n'));
    process.exit(1);
  }
  
  const machines = listMachines();
  
  if (machines.length === 0) {
    console.log(chalk.yellow('⚠️  No machines configured'));
    return;
  }
  
  let totalServices = 0;
  
  for (let i = 0; i < machines.length; i++) {
    const { name: machineName, config: machineConfig } = machines[i]!;
    
    if (i > 0) {
      console.log('\n' + chalk.gray('═'.repeat(80)) + '\n');
    }
    
    console.log(chalk.magenta(`Machine: ${machineName} (${machineConfig.hostname})`));
    console.log(chalk.gray('─'.repeat(80)) + '\n');
    
    try {
      const ssh = await createSSHConnection({
        host: machineConfig.hostname,
        username: machineConfig.user,
      });
      
      try {
        const deployedServices = await listDeployedServices(ssh);
        
        if (deployedServices.length === 0) {
          console.log(chalk.gray('  No services deployed'));
          continue;
        }
        
        totalServices += deployedServices.length;
        
        for (let j = 0; j < deployedServices.length; j++) {
          const service = deployedServices[j]!;
          
          if (j > 0) {
            console.log('\n' + chalk.gray('  ─'.repeat(39)) + '\n');
          }
          
          console.log(chalk.cyan(`  [${machineName}:${service}]`));
          await getServiceLogs(ssh, service, { ...options, verbose: false });
        }
      } finally {
        ssh.dispose();
      }
    } catch (error) {
      if (error instanceof Error) {
        console.log(chalk.red(`  ❌ Error connecting to ${machineName}: ${error.message}`));
      }
    }
  }
  
  if (options.verbose) {
    console.log(chalk.gray(`\nTotal services: ${totalServices}`));
  }
}

