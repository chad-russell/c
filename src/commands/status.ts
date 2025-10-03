/**
 * Status command - Check deployment status with metrics and drift detection
 */

import chalk from 'chalk';
import { getMachineConfig } from '../lib/config.ts';
import { createSSHConnection } from '../lib/ssh.ts';
import {
  listDeployedServices,
  getServiceStatus,
  getServiceMetrics,
} from '../lib/systemd.ts';
import type { CommandOptions, StatusResult } from '../types.ts';

interface StatusCommandOptions extends CommandOptions {
  metrics?: boolean;
}

export async function statusCommand(
  machineName: string,
  options: StatusCommandOptions = {}
): Promise<void> {
  try {
    console.log(chalk.blue(`\n📊 Status for machine: ${machineName}\n`));
    
    // Load machine configuration
    const machineConfig = getMachineConfig(machineName);
    
    if (options.verbose) {
      console.log(chalk.gray(`  Host: ${machineConfig.hostname}`));
      console.log(chalk.gray(`  User: ${machineConfig.user}`));
      console.log(chalk.gray(`  Configured services: ${machineConfig.services.join(', ')}\n`));
    }
    
    // Connect to machine
    const ssh = await createSSHConnection({
      host: machineConfig.hostname,
      username: machineConfig.user,
    });
    
    try {
      // Get deployed services
      const deployedServices = await listDeployedServices(ssh);
      
      // Build status result
      const result: StatusResult = {
        machine: machineName,
        services: [],
        drift: {
          shouldBeDeployed: [],
          orphaned: [],
        },
      };
      
      // Check each deployed service
      for (const serviceName of deployedServices) {
        const status = await getServiceStatus(ssh, serviceName);
        const inConfig = machineConfig.services.includes(serviceName);
        
        // Get metrics if requested or always show them
        let metrics = undefined;
        if (status.active) {
          metrics = await getServiceMetrics(ssh, serviceName) || undefined;
        }
        
        result.services.push({
          name: serviceName,
          status,
          metrics,
          inConfig,
        });
        
        // Track orphaned services
        if (!inConfig) {
          result.drift.orphaned.push(serviceName);
        }
      }
      
      // Check for services that should be deployed but aren't
      for (const serviceName of machineConfig.services) {
        if (!deployedServices.includes(serviceName)) {
          result.drift.shouldBeDeployed.push(serviceName);
        }
      }
      
      // Display results
      displayStatus(result, options);
      
    } finally {
      ssh.dispose();
    }
  } catch (error) {
    if (error instanceof Error) {
      console.log(chalk.red(`\n❌ Error: ${error.message}\n`));
    }
    process.exit(1);
  }
}

/**
 * Display the status result with colored output
 */
function displayStatus(result: StatusResult, options: StatusCommandOptions): void {
  // Show drift warnings first
  if (result.drift.shouldBeDeployed.length > 0) {
    console.log(chalk.yellow('⚠️  Services in config but not deployed:'));
    for (const service of result.drift.shouldBeDeployed) {
      console.log(chalk.yellow(`   - ${service}`));
    }
    console.log();
  }
  
  if (result.drift.orphaned.length > 0) {
    console.log(chalk.yellow('⚠️  Services deployed but not in config (orphaned):'));
    for (const service of result.drift.orphaned) {
      console.log(chalk.yellow(`   - ${service}`));
    }
    console.log();
  }
  
  // Show deployed services
  if (result.services.length === 0) {
    console.log(chalk.gray('No services deployed on this machine\n'));
    return;
  }
  
  console.log(chalk.bold('Deployed Services:\n'));
  
  for (const serviceInfo of result.services) {
    const { name, status, metrics, inConfig } = serviceInfo;
    
    // Service name with status indicator
    let statusIcon = '●';
    let statusColor = chalk.gray;
    
    if (status.failed) {
      statusIcon = '✗';
      statusColor = chalk.red;
    } else if (status.active) {
      statusIcon = '✓';
      statusColor = chalk.green;
    } else {
      statusIcon = '○';
      statusColor = chalk.yellow;
    }
    
    console.log(statusColor(`${statusIcon} ${name}`) + (!inConfig ? chalk.yellow(' [orphaned]') : ''));
    
    // Status details
    const statusParts: string[] = [];
    if (status.active) {
      statusParts.push(chalk.green('active'));
    } else {
      statusParts.push(chalk.gray('inactive'));
    }
    
    if (status.enabled) {
      statusParts.push(chalk.gray('enabled'));
    } else {
      statusParts.push(chalk.gray('disabled'));
    }
    
    if (status.failed) {
      statusParts.push(chalk.red('failed'));
    }
    
    console.log(chalk.gray(`  Status: ${statusParts.join(', ')}`));
    
    // Container info
    if (status.containers.length > 0) {
      console.log(chalk.gray(`  Containers: ${status.containers.length}`));
      for (const container of status.containers) {
        console.log(chalk.gray(`    - ${container.name}: ${container.status}`));
      }
    }
    
    // Metrics
    if (metrics && metrics.containers.length > 0) {
      console.log(chalk.gray('  Metrics:'));
      for (const containerMetrics of metrics.containers) {
        console.log(chalk.gray(`    ${containerMetrics.name}:`));
        console.log(chalk.gray(`      CPU:     ${containerMetrics.cpu}`));
        console.log(chalk.gray(`      Memory:  ${containerMetrics.memory}`));
        console.log(chalk.gray(`      Network: ${containerMetrics.network}`));
      }
    }
    
    console.log();
  }
  
  // Summary
  const activeCount = result.services.filter(s => s.status.active).length;
  const failedCount = result.services.filter(s => s.status.failed).length;
  const totalCount = result.services.length;
  
  console.log(chalk.bold('Summary:'));
  console.log(chalk.gray(`  Total: ${totalCount}`));
  console.log(chalk.green(`  Active: ${activeCount}`));
  if (failedCount > 0) {
    console.log(chalk.red(`  Failed: ${failedCount}`));
  }
  if (result.drift.orphaned.length > 0) {
    console.log(chalk.yellow(`  Orphaned: ${result.drift.orphaned.length}`));
  }
  if (result.drift.shouldBeDeployed.length > 0) {
    console.log(chalk.yellow(`  Missing: ${result.drift.shouldBeDeployed.length}`));
  }
  console.log();
}

