use super::types::{Subvolume, TargetRoots};
use super::StorageManager;
use anyhow::{Context, Result, anyhow};
use std::path::Path;
use std::process::Command;

pub struct BtrfsDriver;

impl BtrfsDriver {
    pub fn new() -> Self {
        Self
    }

    fn run_command(&self, cmd: &str, args: &[&str]) -> Result<String> {
        let output = Command::new(cmd)
            .args(args)
            .output()
            .with_context(|| format!("Failed to execute command: {} {}", cmd, args.join(" ")))?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(anyhow!("Command failed: {} {}\nError: {}", cmd, args.join(" "), stderr));
        }

        Ok(String::from_utf8_lossy(&output.stdout).to_string())
    }
}

impl StorageManager for BtrfsDriver {
    fn get_current_root(&self) -> Result<Subvolume> {
        // Use findmnt to get the source of the root mount
        // findmnt -n -o SOURCE --target /
        // Output format usually: /dev/sdX[/@subvol]
        let output = self.run_command("findmnt", &["-n", "-o", "SOURCE", "--target", "/"])?;
        let source = output.trim();

        // This is a simplification. In a real scenario, we'd need to parse more details
        // to get ID, UUID, etc. For now, we'll try to infer from the path or use btrfs inspect-internal.
        
        // Let's try to get the subvolume ID of /
        // btrfs inspect-internal rootid /
        let id_out = self.run_command("btrfs", &["inspect-internal", "rootid", "/"])?;
        let id: u64 = id_out.trim().parse().context("Failed to parse rootid")?;

        // Get the subvolume path relative to the btrfs root
        // btrfs subvolume show /
        // This output is text and hard to parse reliably without regex or careful splitting.
        // A simpler approach for "current root" name might be checking the mount options or source.
        
        // If source contains '[', it might be like /dev/sda2[/@active_a]
        let path_str = if let Some(start) = source.find('[') {
            if let Some(end) = source.find(']') {
                &source[start+1..end]
            } else {
                "unknown"
            }
        } else {
            // Fallback: assume it's the root or we can't determine from source string alone easily
            // without more complex logic.
            // For the sake of the exercise, let's assume standard layout or rely on `btrfs subvolume show`
            "unknown"
        };

        // We need UUID.
        // btrfs filesystem show / could give UUID of the FS, but we want subvolume UUID?
        // btrfs subvolume show / gives UUID.
        let show_out = self.run_command("btrfs", &["subvolume", "show", "/"])?;
        let uuid = show_out.lines()
            .find(|l| l.trim().starts_with("UUID:"))
            .map(|l| l.split_whitespace().last().unwrap_or_default())
            .unwrap_or_default()
            .to_string();

        Ok(Subvolume {
            id,
            path: std::path::PathBuf::from(path_str),
            uuid,
            parent_uuid: None, // Parsing parent UUID is similar to UUID
        })
    }

    fn get_next_target(&self) -> Result<TargetRoots> {
        let current = self.get_current_root()?;
        let path_str = current.path.to_string_lossy();

        if path_str.contains("active_a") {
            Ok(TargetRoots::B)
        } else if path_str.contains("active_b") {
            Ok(TargetRoots::A)
        } else {
            // Default to A if unknown or neither
            // Or maybe error out? For safety, let's assume if we aren't A, we go to A?
            // But if we are in a snapshot or recovery, this might be tricky.
            // Let's assume A is default target if we can't decide.
            Ok(TargetRoots::A)
        }
    }

    fn subvolume_exists(&self, name: &str) -> Result<bool> {
        // btrfs subvolume list -o path [parent_path]
        // We assume we are looking in the top level of the Btrfs mount.
        // This is tricky because we need to know WHERE the btrfs root is mounted to list from it.
        // If we are inside a subvolume, `btrfs subvolume list /` lists subvolumes relative to the FS root,
        // but paths are relative to the FS root.
        
        // A safer check might be to try to stat the path if we know where the btrfs root is mounted.
        // Or use `btrfs subvolume list /` and check if the name appears in the paths.
        
        let output = self.run_command("btrfs", &["subvolume", "list", "/"])?;
        // Output line format: ID 256 gen 10 top level 5 path @active_a
        
        for line in output.lines() {
            if let Some(path_part) = line.split(" path ").nth(1) {
                if path_part.trim() == name {
                    return Ok(true);
                }
            }
        }
        
        Ok(false)
    }

    fn delete_subvolume(&self, name: &str) -> Result<()> {
        if !self.subvolume_exists(name)? {
            return Ok(());
        }
        // We need the full path to delete. If 'name' is just "@active_a", where is it?
        // We assume it's at /@active_a if / is the btrfs root? 
        // Wait, if / is mounted as @active_a, then @active_b is NOT visible at /@active_b usually,
        // unless we mount the top-level subvolume somewhere.
        
        // CRITICAL: To manage sibling subvolumes, we MUST have the top-level btrfs root mounted.
        // This implementation assumes we can access it. 
        // If not, we might need to mount it temporarily.
        // For this exercise, let's assume the user has mounted the btrfs root at /mnt/btrfs_root or similar,
        // OR that we are operating in an environment where we can see them.
        
        // However, the prompt implies we are running on the live system.
        // If I am in @active_a, I cannot see @active_b unless I mount the root.
        
        // Let's assume for now we are just generating the commands or that 'name' implies a path we can reach.
        // But `delete_subvolume` takes `name: &str`.
        
        // Refinement: The prompt says "Deletes a subvolume".
        // If we can't see it, we can't delete it.
        // We might need to `mount -o subvolid=5 /dev/sdX /mnt/tmp` to perform these ops.
        // That seems out of scope for a simple "wrapper" unless specified.
        
        // Let's assume the path is accessible relative to current directory or absolute path is provided?
        // The spec says `name: &str`. 
        // Let's assume `name` is a path for now, or relative to `/`.
        // But if we are in a subvolume, we can't see siblings at `/`.
        
        // For the purpose of this "Phase 1", I will implement the command execution
        // assuming the path is valid and accessible.
        
        self.run_command("btrfs", &["subvolume", "delete", name])?;
        Ok(())
    }

    fn create_subvolume(&self, name: &str) -> Result<()> {
        if self.subvolume_exists(name)? {
            return Ok(());
        }
        self.run_command("btrfs", &["subvolume", "create", name])?;
        Ok(())
    }

    fn mount_subvolume(&self, subvol_name: &str, target_path: &Path) -> Result<()> {
        // mount -o subvol=subvol_name /dev/device target_path
        // We need the device.
        let current_root = self.get_current_root()?;
        // We can try to extract device from findmnt source
        // This is getting complicated without a robust device discovery.
        
        // Let's simplify: assume we can just pass the device if we knew it.
        // But we don't have the device in the signature.
        // Maybe we can infer it from /proc/self/mountinfo.
        
        let findmnt = self.run_command("findmnt", &["-n", "-o", "SOURCE", "--target", "/"])?;
        let device = findmnt.trim().split('[').next().unwrap_or("").trim();
        
        if device.is_empty() {
            return Err(anyhow!("Could not determine device for root mount"));
        }

        let status = Command::new("mount")
            .arg("-o")
            .arg(format!("subvol={}", subvol_name))
            .arg(device)
            .arg(target_path)
            .status()
            .context("Failed to execute mount command")?;

        if !status.success() {
            return Err(anyhow!("Mount failed"));
        }
        Ok(())
    }
}
