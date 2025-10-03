/**
 * Service management module
 * Handles local service file operations
 */

import { readdirSync, statSync, readFileSync } from 'fs';
import { join, extname, basename } from 'path';
import { createHash } from 'crypto';
import { getServiceDir } from './config.ts';
import type { QuadletFile } from '../types.ts';

const QUADLET_EXTENSIONS = ['.container', '.network', '.volume', '.pod', '.kube', '.build', '.image'];

/**
 * Check if a service directory exists
 */
export function serviceExists(serviceName: string): boolean {
  try {
    const serviceDir = getServiceDir(serviceName);
    const stat = statSync(serviceDir);
    return stat.isDirectory();
  } catch {
    return false;
  }
}

/**
 * Get all quadlet files for a service
 */
export function getServiceFiles(serviceName: string): QuadletFile[] {
  const serviceDir = getServiceDir(serviceName);
  const files: QuadletFile[] = [];
  
  try {
    const entries = readdirSync(serviceDir);
    
    for (const entry of entries) {
      const ext = extname(entry);
      
      if (QUADLET_EXTENSIONS.includes(ext)) {
        const fullPath = join(serviceDir, entry);
        const checksum = getFileChecksum(fullPath);
        
        files.push({
          filename: entry,
          type: ext.slice(1) as QuadletFile['type'],
          serviceName,
          path: fullPath,
          checksum,
        });
      }
    }
    
    return files;
  } catch (error) {
    if (error instanceof Error) {
      throw new Error(`Failed to read service directory ${serviceDir}: ${error.message}`);
    }
    throw error;
  }
}

/**
 * Calculate SHA256 checksum of a file
 */
export function getFileChecksum(filePath: string): string {
  const content = readFileSync(filePath);
  return createHash('sha256').update(content).digest('hex');
}

/**
 * Validate that a service has at least one main unit file
 * (container, pod, or kube)
 */
export function validateService(serviceName: string): { valid: boolean; error?: string } {
  const files = getServiceFiles(serviceName);
  
  if (files.length === 0) {
    return {
      valid: false,
      error: `No quadlet files found in services/${serviceName}/`,
    };
  }
  
  // Check for at least one main unit type
  const hasMainUnit = files.some(f => 
    f.type === 'container' || f.type === 'pod' || f.type === 'kube'
  );
  
  if (!hasMainUnit) {
    return {
      valid: false,
      error: `Service must have at least one .container, .pod, or .kube file`,
    };
  }
  
  return { valid: true };
}

/**
 * Get the main service name from quadlet files
 * (the service that should be started)
 */
export function getMainServiceName(serviceName: string): string {
  const files = getServiceFiles(serviceName);
  
  // Find the main container file (without suffix)
  const mainFile = files.find(f => 
    (f.type === 'container' || f.type === 'pod' || f.type === 'kube') &&
    basename(f.filename, extname(f.filename)) === serviceName
  );
  
  if (mainFile) {
    return serviceName;
  }
  
  // If no exact match, find any container/pod/kube file
  const anyMain = files.find(f => 
    f.type === 'container' || f.type === 'pod' || f.type === 'kube'
  );
  
  if (anyMain) {
    return basename(anyMain.filename, extname(anyMain.filename));
  }
  
  // Fallback to service name
  return serviceName;
}

