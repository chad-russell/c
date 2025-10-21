/**
 * List command - Show all configured machines
 */

import chalk from 'chalk';
import { listMachines } from '../lib/config.ts';

export async function listCommand(): Promise<void> {
  try {
    const machines = listMachines();
    
    if (machines.length === 0) {
      console.log(chalk.yellow('\n⚠️  No machines configured in machines/machines.yaml'));
      console.log(chalk.gray('\nAdd machines to machines/machines.yaml to get started.'));
      return;
    }
    
    console.log(chalk.blue('\n📋 Configured Machines\n'));
    
    for (const { name, config } of machines) {
      console.log(chalk.bold.cyan(`  ${name}`));
      console.log(chalk.gray(`    Host:     ${config.hostname}`));
      console.log(chalk.gray(`    User:     ${config.user}`));
      
      if (config.description) {
        console.log(chalk.gray(`    About:    ${config.description}`));
      }
      
      if (config.services.length > 0) {
        console.log(chalk.gray(`    Services: ${config.services.join(', ')}`));
      } else {
        console.log(chalk.gray(`    Services: (none)`));
      }
      
      console.log(); // Empty line between machines
    }
    
    console.log(chalk.gray(`Total: ${machines.length} machine${machines.length === 1 ? '' : 's'}\n`));
  } catch (error) {
    if (error instanceof Error) {
      console.error(chalk.red(`\n❌ Error: ${error.message}\n`));
      process.exit(1);
    }
    throw error;
  }
}

