/**
 * Configuration management module
 * Loads and validates machines.yaml
 */

import { readFileSync } from 'fs';
import { resolve, dirname } from 'path';
import yaml from 'js-yaml';
import { MachinesConfigSchema, type MachinesConfig, type MachineConfig } from '../types.ts';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

/**
 * Get the project root directory
 */
function getProjectRoot(): string {
  // src/lib/config.ts -> go up two levels
  return resolve(__dirname, '..', '..');
}

/**
 * Load and parse machines.yaml
 */
export function loadMachinesConfig(): MachinesConfig {
  const configPath = resolve(getProjectRoot(), 'machines', 'machines.yaml');
  
  try {
    const fileContent = readFileSync(configPath, 'utf-8');
    const parsed = yaml.load(fileContent);
    
    // Validate with Zod
    const validated = MachinesConfigSchema.parse(parsed);
    return validated;
  } catch (error) {
    if (error instanceof Error) {
      throw new Error(`Failed to load machines config: ${error.message}`);
    }
    throw error;
  }
}

/**
 * Get configuration for a specific machine
 */
export function getMachineConfig(machineName: string): MachineConfig {
  const config = loadMachinesConfig();
  const machineConfig = config.machines[machineName];
  
  if (!machineConfig) {
    const availableMachines = Object.keys(config.machines).join(', ');
    throw new Error(
      `Machine "${machineName}" not found in machines.yaml. ` +
      `Available machines: ${availableMachines || 'none'}`
    );
  }
  
  return machineConfig;
}

/**
 * List all configured machines
 */
export function listMachines(): Array<{ name: string; config: MachineConfig }> {
  const config = loadMachinesConfig();
  return Object.entries(config.machines).map(([name, config]) => ({
    name,
    config,
  }));
}

/**
 * Get the services directory path
 */
export function getServicesDir(): string {
  return resolve(getProjectRoot(), 'services');
}

/**
 * Get the path to a specific service directory
 */
export function getServiceDir(serviceName: string): string {
  return resolve(getServicesDir(), serviceName);
}

/**
 * Find which machine(s) have a specific service configured
 */
export function findMachineForService(serviceName: string): string[] {
  const config = loadMachinesConfig();
  const machinesWithService: string[] = [];
  
  for (const [machineName, machineConfig] of Object.entries(config.machines)) {
    if (machineConfig.services.includes(serviceName)) {
      machinesWithService.push(machineName);
    }
  }
  
  return machinesWithService;
}

