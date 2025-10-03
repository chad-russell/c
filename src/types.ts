/**
 * Type definitions for the homelab deployment system
 */

import { z } from 'zod';

/**
 * Machine configuration schema
 */
export const MachineConfigSchema = z.object({
  hostname: z.string().describe('IP address or hostname of the machine'),
  user: z.string().describe('SSH user to connect as'),
  description: z.string().optional().describe('Human-readable description of the machine'),
  services: z.array(z.string()).describe('List of services to deploy to this machine'),
});

export type MachineConfig = z.infer<typeof MachineConfigSchema>;

/**
 * Machines file schema (machines.yaml)
 */
export const MachinesConfigSchema = z.object({
  machines: z.record(z.string(), MachineConfigSchema),
});

export type MachinesConfig = z.infer<typeof MachinesConfigSchema>;

/**
 * Service deployment state
 */
export interface ServiceState {
  name: string;
  files: string[];
  deployed: boolean;
  status?: 'running' | 'stopped' | 'failed' | 'unknown';
}

/**
 * Deployment plan showing what will change
 */
export interface DeploymentPlan {
  machine: string;
  servicesToAdd: string[];
  servicesToRemove: string[];
  servicesToUpdate: string[];
  filesToCopy: Array<{ local: string; remote: string; checksum: string }>;
}

/**
 * Deployment result
 */
export interface DeploymentResult {
  success: boolean;
  machine: string;
  servicesDeployed: string[];
  servicesRemoved: string[];
  errors: Array<{ service: string; error: string }>;
}

/**
 * Quadlet file types
 */
export type QuadletFileType = 'container' | 'network' | 'volume' | 'pod' | 'kube' | 'build' | 'image';

/**
 * Quadlet file info
 */
export interface QuadletFile {
  filename: string;
  type: QuadletFileType;
  serviceName: string;
  path: string;
  checksum?: string;
}

/**
 * SSH connection options
 */
export interface SSHConnectionOptions {
  host: string;
  username: string;
  privateKeyPath?: string;
  port?: number;
  timeout?: number;
}

/**
 * Command options
 */
export interface CommandOptions {
  dryRun?: boolean;
  verbose?: boolean;
  service?: string;
  yes?: boolean;
}

/**
 * Status information for a deployed service
 */
export interface ServiceStatus {
  name: string;
  deployed: boolean;
  active: boolean;
  enabled: boolean;
  failed: boolean;
  containers: Array<{
    name: string;
    status: string;
  }>;
}

