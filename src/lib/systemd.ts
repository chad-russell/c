/**
 * Systemd operations module
 * Manages systemd services on remote machines (rootless mode)
 */

import type { NodeSSH } from 'node-ssh';
import { executeCommand, listRemoteFiles } from './ssh.ts';
import type { QuadletFile, ServiceStatus } from '../types.ts';
import { basename, extname } from 'path';

const SYSTEMD_USER_DIR = '~/.config/containers/systemd';
const QUADLET_EXTENSIONS = ['.container', '.network', '.volume', '.pod', '.kube', '.build', '.image'];

/**
 * List all quadlet files deployed on the remote machine
 */
export async function listDeployedQuadletFiles(ssh: NodeSSH): Promise<QuadletFile[]> {
  const files: QuadletFile[] = [];
  
  for (const ext of QUADLET_EXTENSIONS) {
    const pattern = `*${ext}`;
    const remoteFiles = await listRemoteFiles(ssh, SYSTEMD_USER_DIR, pattern);
    
    for (const filename of remoteFiles) {
      const file = basename(filename);
      const serviceName = parseServiceName(file);
      const type = ext.slice(1) as QuadletFile['type'];
      
      files.push({
        filename: file,
        type,
        serviceName,
        path: `${SYSTEMD_USER_DIR}/${file}`,
      });
    }
  }
  
  return files;
}

/**
 * Parse service name from a quadlet filename
 * Examples:
 *   pinepods.container -> pinepods
 *   pinepods-db.container -> pinepods
 *   pinepods-pgdata.volume -> pinepods
 */
export function parseServiceName(filename: string): string {
  const name = basename(filename, extname(filename));
  
  // Remove common suffixes
  const parts = name.split('-');
  
  // If it's just servicename.ext, return as-is
  if (parts.length === 1) {
    return parts[0]!;
  }
  
  // For patterns like servicename-db, servicename-cache, etc.
  // Return the first part as the service name
  return parts[0]!;
}

/**
 * Get all services deployed on the machine
 * Groups quadlet files by service name
 */
export async function listDeployedServices(ssh: NodeSSH): Promise<string[]> {
  const files = await listDeployedQuadletFiles(ssh);
  const services = new Set(files.map(f => f.serviceName));
  return Array.from(services).sort();
}

/**
 * Reload systemd daemon (after adding/removing quadlet files)
 */
export async function reloadSystemdDaemon(
  ssh: NodeSSH,
  options?: { verbose?: boolean }
): Promise<void> {
  if (options?.verbose) {
    console.log('Reloading systemd daemon...');
  }
  
  const result = await executeCommand(ssh, 'systemctl --user daemon-reload', options);
  
  if (result.code !== 0) {
    throw new Error(`Failed to reload systemd daemon: ${result.stderr}`);
  }
}

/**
 * Start a systemd service
 */
export async function startService(
  ssh: NodeSSH,
  serviceName: string,
  options?: { verbose?: boolean }
): Promise<void> {
  if (options?.verbose) {
    console.log(`Starting ${serviceName}.service...`);
  }
  
  const result = await executeCommand(
    ssh,
    `systemctl --user start ${serviceName}.service`,
    options
  );
  
  if (result.code !== 0) {
    throw new Error(`Failed to start ${serviceName}: ${result.stderr}`);
  }
}

/**
 * Stop a systemd service
 */
export async function stopService(
  ssh: NodeSSH,
  serviceName: string,
  options?: { verbose?: boolean }
): Promise<void> {
  if (options?.verbose) {
    console.log(`Stopping ${serviceName}.service...`);
  }
  
  const result = await executeCommand(
    ssh,
    `systemctl --user stop ${serviceName}.service`,
    options
  );
  
  if (result.code !== 0) {
    throw new Error(`Failed to stop ${serviceName}: ${result.stderr}`);
  }
}

/**
 * Enable a systemd service (start on boot)
 */
export async function enableService(
  ssh: NodeSSH,
  serviceName: string,
  options?: { verbose?: boolean }
): Promise<void> {
  if (options?.verbose) {
    console.log(`Enabling ${serviceName}.service...`);
  }
  
  const result = await executeCommand(
    ssh,
    `systemctl --user enable ${serviceName}.service`,
    options
  );
  
  if (result.code !== 0) {
    throw new Error(`Failed to enable ${serviceName}: ${result.stderr}`);
  }
}

/**
 * Disable a systemd service
 */
export async function disableService(
  ssh: NodeSSH,
  serviceName: string,
  options?: { verbose?: boolean }
): Promise<void> {
  if (options?.verbose) {
    console.log(`Disabling ${serviceName}.service...`);
  }
  
  const result = await executeCommand(
    ssh,
    `systemctl --user disable ${serviceName}.service 2>/dev/null || true`,
    options
  );
}

/**
 * Get the status of a service
 */
export async function getServiceStatus(
  ssh: NodeSSH,
  serviceName: string
): Promise<ServiceStatus> {
  // Check if service is active
  const activeResult = await executeCommand(
    ssh,
    `systemctl --user is-active ${serviceName}.service 2>/dev/null || echo "inactive"`
  );
  const active = activeResult.stdout.trim() === 'active';
  
  // Check if service is enabled
  const enabledResult = await executeCommand(
    ssh,
    `systemctl --user is-enabled ${serviceName}.service 2>/dev/null || echo "disabled"`
  );
  const enabled = enabledResult.stdout.trim() === 'enabled';
  
  // Check if service failed
  const failedResult = await executeCommand(
    ssh,
    `systemctl --user is-failed ${serviceName}.service 2>/dev/null || echo "not-failed"`
  );
  const failed = failedResult.stdout.trim() === 'failed';
  
  // Get container info if running
  const containers: Array<{ name: string; status: string }> = [];
  if (active) {
    const psResult = await executeCommand(
      ssh,
      `podman ps --filter "name=${serviceName}" --format "{{.Names}} {{.Status}}" 2>/dev/null || true`
    );
    
    if (psResult.stdout.trim()) {
      for (const line of psResult.stdout.split('\n')) {
        const [name, ...statusParts] = line.trim().split(/\s+/);
        if (name) {
          containers.push({
            name,
            status: statusParts.join(' '),
          });
        }
      }
    }
  }
  
  return {
    name: serviceName,
    deployed: true,
    active,
    enabled,
    failed,
    containers,
  };
}

/**
 * Ensure the systemd user directory exists
 */
export async function ensureSystemdUserDir(
  ssh: NodeSSH,
  options?: { verbose?: boolean }
): Promise<void> {
  if (options?.verbose) {
    console.log(`Ensuring ${SYSTEMD_USER_DIR} exists...`);
  }
  
  await executeCommand(ssh, `mkdir -p ${SYSTEMD_USER_DIR}`, options);
}

/**
 * Remove quadlet files for a service
 */
export async function removeServiceFiles(
  ssh: NodeSSH,
  serviceName: string,
  options?: { verbose?: boolean }
): Promise<string[]> {
  if (options?.verbose) {
    console.log(`Removing quadlet files for ${serviceName}...`);
  }
  
  const files = await listDeployedQuadletFiles(ssh);
  const serviceFiles = files.filter(f => f.serviceName === serviceName);
  const removedFiles: string[] = [];
  
  for (const file of serviceFiles) {
    const result = await executeCommand(
      ssh,
      `rm -f "${SYSTEMD_USER_DIR}/${file.filename}"`,
      options
    );
    
    if (result.code === 0) {
      removedFiles.push(file.filename);
    }
  }
  
  return removedFiles;
}

