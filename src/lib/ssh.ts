/**
 * SSH operations module
 * Handles remote command execution and file transfers
 */

import { NodeSSH } from 'node-ssh';
import type { SSHConnectionOptions } from '../types.ts';
import { homedir } from 'os';
import { resolve } from 'path';

/**
 * Create and connect an SSH client
 */
export async function createSSHConnection(options: SSHConnectionOptions): Promise<NodeSSH> {
  const ssh = new NodeSSH();
  
  try {
    // Use SSH agent for authentication (handles encrypted keys)
    await ssh.connect({
      host: options.host,
      username: options.username,
      agent: process.env.SSH_AUTH_SOCK,
      port: options.port || 22,
      readyTimeout: options.timeout || 30000,
    });
    
    return ssh;
  } catch (error) {
    if (error instanceof Error) {
      throw new Error(`Failed to connect to ${options.host}: ${error.message}`);
    }
    throw error;
  }
}

/**
 * Execute a command on the remote machine
 */
export async function executeCommand(
  ssh: NodeSSH,
  command: string,
  options?: { verbose?: boolean }
): Promise<{ stdout: string; stderr: string; code: number }> {
  try {
    const result = await ssh.execCommand(command);
    
    if (options?.verbose) {
      console.log(`Command: ${command}`);
      if (result.stdout) console.log(`stdout: ${result.stdout}`);
      if (result.stderr) console.log(`stderr: ${result.stderr}`);
      console.log(`exit code: ${result.code}`);
    }
    
    return {
      stdout: result.stdout,
      stderr: result.stderr,
      code: result.code || 0,
    };
  } catch (error) {
    if (error instanceof Error) {
      throw new Error(`Command failed: ${error.message}`);
    }
    throw error;
  }
}

/**
 * Upload a file to the remote machine
 */
export async function uploadFile(
  ssh: NodeSSH,
  localPath: string,
  remotePath: string,
  options?: { verbose?: boolean }
): Promise<void> {
  try {
    if (options?.verbose) {
      console.log(`Uploading ${localPath} -> ${remotePath}`);
    }
    
    await ssh.putFile(localPath, remotePath);
  } catch (error) {
    if (error instanceof Error) {
      throw new Error(`Failed to upload file: ${error.message}`);
    }
    throw error;
  }
}

/**
 * Upload multiple files to the remote machine
 */
export async function uploadFiles(
  ssh: NodeSSH,
  files: Array<{ local: string; remote: string }>,
  options?: { verbose?: boolean }
): Promise<void> {
  try {
    if (options?.verbose) {
      console.log(`Uploading ${files.length} files...`);
    }
    
    await ssh.putFiles(files);
  } catch (error) {
    if (error instanceof Error) {
      throw new Error(`Failed to upload files: ${error.message}`);
    }
    throw error;
  }
}

/**
 * Download a file from the remote machine
 */
export async function downloadFile(
  ssh: NodeSSH,
  remotePath: string,
  localPath: string,
  options?: { verbose?: boolean }
): Promise<void> {
  try {
    if (options?.verbose) {
      console.log(`Downloading ${remotePath} -> ${localPath}`);
    }
    
    await ssh.getFile(localPath, remotePath);
  } catch (error) {
    if (error instanceof Error) {
      throw new Error(`Failed to download file: ${error.message}`);
    }
    throw error;
  }
}

/**
 * Check if a remote path exists
 */
export async function remotePathExists(
  ssh: NodeSSH,
  path: string
): Promise<boolean> {
  const result = await executeCommand(ssh, `test -e "${path}" && echo "exists" || echo "not found"`);
  return result.stdout.trim() === 'exists';
}

/**
 * List files in a remote directory
 */
export async function listRemoteFiles(
  ssh: NodeSSH,
  directory: string,
  pattern?: string
): Promise<string[]> {
  // Expand tilde in shell for proper path resolution
  const command = pattern 
    ? `ls -1 ${directory}/${pattern} 2>/dev/null || true`
    : `ls -1 ${directory} 2>/dev/null || true`;
  
  const result = await executeCommand(ssh, command);
  
  if (!result.stdout.trim()) {
    return [];
  }
  
  return result.stdout.split('\n').filter(line => line.trim());
}

/**
 * Get the checksum of a remote file
 */
export async function getRemoteFileChecksum(
  ssh: NodeSSH,
  path: string
): Promise<string | null> {
  const result = await executeCommand(ssh, `sha256sum "${path}" 2>/dev/null || true`);
  
  if (!result.stdout.trim()) {
    return null;
  }
  
  // sha256sum output: "checksum  filename"
  return result.stdout.split(/\s+/)[0] || null;
}

/**
 * Compare local and remote file checksums to detect drift
 * Returns true if files differ or remote file doesn't exist
 */
export async function hasFileDrift(
  ssh: NodeSSH,
  localChecksum: string,
  remotePath: string
): Promise<boolean> {
  const remoteChecksum = await getRemoteFileChecksum(ssh, remotePath);
  
  // If remote file doesn't exist or checksums differ, there's drift
  return remoteChecksum === null || remoteChecksum !== localChecksum;
}

