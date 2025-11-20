use anyhow::Result;
use std::path::Path;

pub mod types;
pub mod btrfs;

use types::{Subvolume, TargetRoots};

pub trait StorageManager {
    /// Returns the subvolume currently mounted at /
    fn get_current_root(&self) -> Result<Subvolume>;

    /// Determines which root is the "next" target (The one NOT running)
    fn get_next_target(&self) -> Result<TargetRoots>;

    /// Checks if a subvolume exists by name
    fn subvolume_exists(&self, name: &str) -> Result<bool>;

    /// Deletes a subvolume (and all nested children, if strictly required)
    fn delete_subvolume(&self, name: &str) -> Result<()>;

    /// Creates a new, empty subvolume
    fn create_subvolume(&self, name: &str) -> Result<()>;
    
    /// Mounts a subvolume to a specific path (wraps `mount -o subvol=...`)
    fn mount_subvolume(&self, subvol_name: &str, target_path: &Path) -> Result<()>;
}
