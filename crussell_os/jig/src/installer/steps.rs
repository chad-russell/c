use super::InstallerStep;
use anyhow::{Result, anyhow, Context};
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::io::Write;
use std::fs;
use log::info;

// --- Step 1: Partitioning ---
pub struct PartitionDisk {
    pub disk: PathBuf,
}

impl InstallerStep for PartitionDisk {
    fn name(&self) -> &str {
        "Partition Disk"
    }

    fn run(&self) -> Result<()> {
        info!("Partitioning disk: {:?}", self.disk);
        
        // sfdisk script:
        // label: gpt
        // size=1G, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B (EFI System Partition)
        // type=0FC63DAF-8483-4772-8E79-3D69D8477DE4 (Linux Filesystem)
        let script = "label: gpt\nsize=1G, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B\ntype=0FC63DAF-8483-4772-8E79-3D69D8477DE4\n";

        let mut child = Command::new("sfdisk")
            .arg(&self.disk)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()
            .context("Failed to spawn sfdisk")?;

        if let Some(mut stdin) = child.stdin.take() {
            stdin.write_all(script.as_bytes()).context("Failed to write to sfdisk stdin")?;
        }

        let output = child.wait_with_output().context("Failed to wait for sfdisk")?;

        if !output.status.success() {
            return Err(anyhow!("sfdisk failed: {}", String::from_utf8_lossy(&output.stderr)));
        }

        // Wait a moment for kernel to update partition table
        std::thread::sleep(std::time::Duration::from_secs(2));
        Ok(())
    }

    fn verify(&self) -> Result<()> {
        // Check if partitions exist
        // Assuming /dev/vda -> /dev/vda1, /dev/vda2
        // This logic might need adjustment for NVMe drives (p1, p2)
        let disk_str = self.disk.to_string_lossy();
        let p1 = if disk_str.contains("nvme") {
            format!("{}p1", disk_str)
        } else {
            format!("{}1", disk_str)
        };
        let p2 = if disk_str.contains("nvme") {
            format!("{}p2", disk_str)
        } else {
            format!("{}2", disk_str)
        };

        if !Path::new(&p1).exists() || !Path::new(&p2).exists() {
            return Err(anyhow!("Partitions not found after sfdisk"));
        }
        Ok(())
    }
}

// --- Step 2: Formatting ---
pub struct FormatPartitions {
    pub disk: PathBuf,
}

impl InstallerStep for FormatPartitions {
    fn name(&self) -> &str {
        "Format Partitions"
    }

    fn run(&self) -> Result<()> {
        let disk_str = self.disk.to_string_lossy();
        let p1 = if disk_str.contains("nvme") { format!("{}p1", disk_str) } else { format!("{}1", disk_str) };
        let p2 = if disk_str.contains("nvme") { format!("{}p2", disk_str) } else { format!("{}2", disk_str) };

        info!("Formatting EFI partition: {}", p1);
        let status = Command::new("mkfs.fat")
            .arg("-F32")
            .arg(&p1)
            .status()
            .context("Failed to run mkfs.fat")?;
        if !status.success() { return Err(anyhow!("mkfs.fat failed")); }

        info!("Formatting Root partition (Btrfs): {}", p2);
        let status = Command::new("mkfs.btrfs")
            .arg("-f") // Force
            .arg("-L")
            .arg("ROOT")
            .arg(&p2)
            .status()
            .context("Failed to run mkfs.btrfs")?;
        if !status.success() { return Err(anyhow!("mkfs.btrfs failed")); }

        Ok(())
    }

    fn verify(&self) -> Result<()> {
        // Could run blkid to verify types, but for now assume success if commands succeeded
        Ok(())
    }
}

// --- Step 3: Subvolumes ---
pub struct CreateSubvolumes {
    pub disk: PathBuf,
}

impl InstallerStep for CreateSubvolumes {
    fn name(&self) -> &str {
        "Create Subvolumes"
    }

    fn run(&self) -> Result<()> {
        let disk_str = self.disk.to_string_lossy();
        let p2 = if disk_str.contains("nvme") { format!("{}p2", disk_str) } else { format!("{}2", disk_str) };
        let mount_point = Path::new("/tmp/jig-install");

        if !mount_point.exists() {
            fs::create_dir_all(mount_point)?;
        }

        // Mount root
        let status = Command::new("mount")
            .arg(&p2)
            .arg(mount_point)
            .status()
            .context("Failed to mount root for subvol creation")?;
        if !status.success() { return Err(anyhow!("Failed to mount root partition")); }

        let subvols = vec![
            "@active_a", "@active_b", "@snapshots", 
            "@var_log", "@var_cache", "@home_root", "@home_vault"
        ];

        for subvol in subvols {
            info!("Creating subvolume: {}", subvol);
            let status = Command::new("btrfs")
                .arg("subvolume")
                .arg("create")
                .arg(mount_point.join(subvol))
                .status()
                .context(format!("Failed to create subvolume {}", subvol))?;
            if !status.success() { 
                // Try to unmount before returning error
                let _ = Command::new("umount").arg(mount_point).status();
                return Err(anyhow!("Failed to create subvolume {}", subvol)); 
            }
        }

        // Unmount
        let status = Command::new("umount")
            .arg(mount_point)
            .status()
            .context("Failed to unmount root after subvol creation")?;
        if !status.success() { return Err(anyhow!("Failed to unmount root")); }

        Ok(())
    }

    fn verify(&self) -> Result<()> {
        // Verification is implicit if commands succeeded. 
        // To be rigorous, we could mount again and check existence.
        Ok(())
    }
}

// --- Step 4: Mounting Hierarchy ---
pub struct MountHierarchy {
    pub disk: PathBuf,
}

impl InstallerStep for MountHierarchy {
    fn name(&self) -> &str {
        "Mount Hierarchy"
    }

    fn run(&self) -> Result<()> {
        let disk_str = self.disk.to_string_lossy();
        let p1 = if disk_str.contains("nvme") { format!("{}p1", disk_str) } else { format!("{}1", disk_str) };
        let p2 = if disk_str.contains("nvme") { format!("{}p2", disk_str) } else { format!("{}2", disk_str) };
        let target = Path::new("/mnt");

        // Mount @active_a to /mnt
        info!("Mounting @active_a to /mnt");
        let status = Command::new("mount")
            .arg("-o").arg("subvol=@active_a,compress=zstd")
            .arg(&p2)
            .arg(target)
            .status()?;
        if !status.success() { return Err(anyhow!("Failed to mount @active_a")); }

        // Create directories
        let dirs = vec![
            "boot", "home", "var/log", "var/cache", "snapshots", "mnt/vault"
        ];
        for dir in dirs {
            fs::create_dir_all(target.join(dir))?;
        }

        // Mount subvolumes
        let mounts = vec![
            ("@home_root", "home"),
            ("@var_log", "var/log"),
            ("@var_cache", "var/cache"),
            ("@snapshots", "snapshots"),
            ("@home_vault", "mnt/vault"),
        ];

        for (subvol, dir) in mounts {
            info!("Mounting {} to {}", subvol, dir);
            let status = Command::new("mount")
                .arg("-o").arg(format!("subvol={},compress=zstd", subvol))
                .arg(&p2)
                .arg(target.join(dir))
                .status()?;
            if !status.success() { return Err(anyhow!("Failed to mount {}", subvol)); }
        }

        // Mount EFI to /boot (Standard Arch practice for systemd-boot simplicity)
        info!("Mounting EFI partition to /boot");
        let status = Command::new("mount")
            .arg(&p1)
            .arg(target.join("boot"))
            .status()?;
        if !status.success() { return Err(anyhow!("Failed to mount EFI to /boot")); }

        Ok(())
    }

    fn verify(&self) -> Result<()> {
        if !Path::new("/mnt/boot").exists() {
            return Err(anyhow!("/mnt/boot does not exist"));
        }
        Ok(())
    }
}

// --- Step 5: Pacstrap ---
pub struct Pacstrap;

impl InstallerStep for Pacstrap {
    fn name(&self) -> &str {
        "Pacstrap Base System"
    }

    fn run(&self) -> Result<()> {
        info!("Running pacstrap...");
        let status = Command::new("pacstrap")
            .arg("/mnt")
            .args(&["base", "linux", "linux-firmware", "intel-ucode", "btrfs-progs", "systemd", "networkmanager", "vim", "git", "openssh", "sudo"])
            .status()
            .context("Failed to run pacstrap")?;
        
        if !status.success() {
            return Err(anyhow!("Pacstrap failed"));
        }
        Ok(())
    }

    fn verify(&self) -> Result<()> {
        if !Path::new("/mnt/bin/bash").exists() {
            return Err(anyhow!("Base system not found (bash missing)"));
        }
        Ok(())
    }
}

// --- Step 6: System Configuration ---
pub struct ConfigureSystem;

impl InstallerStep for ConfigureSystem {
    fn name(&self) -> &str {
        "Configure System"
    }

    fn run(&self) -> Result<()> {
        // Genfstab
        info!("Generating fstab...");
        let output = Command::new("genfstab")
            .arg("-U")
            .arg("/mnt")
            .output()
            .context("Failed to run genfstab")?;
        
        let mut fstab = fs::OpenOptions::new().append(true).open("/mnt/etc/fstab")?;
        fstab.write_all(&output.stdout)?;

        // Timezone
        info!("Setting timezone...");
        // We need to run this inside chroot or just link it relative to /mnt?
        // Linking /usr/share/zoneinfo/UTC to /mnt/etc/localtime is safer done via chroot or careful symlink
        // But `ln -sf /usr/share/zoneinfo/UTC /mnt/etc/localtime` works if the path exists in host.
        // Better: `arch-chroot /mnt ln -sf /usr/share/zoneinfo/UTC /etc/localtime`
        Command::new("arch-chroot")
            .arg("/mnt")
            .args(&["ln", "-sf", "/usr/share/zoneinfo/UTC", "/etc/localtime"])
            .status()?;

        // Locale
        info!("Setting locale...");
        let mut locale_gen = fs::OpenOptions::new().append(true).open("/mnt/etc/locale.gen")?;
        writeln!(locale_gen, "en_US.UTF-8 UTF-8")?;
        
        Command::new("arch-chroot")
            .arg("/mnt")
            .arg("locale-gen")
            .status()?;

        // Hostname
        info!("Setting hostname...");
        fs::write("/mnt/etc/hostname", "jig")?;

        // User
        info!("Creating user 'crussell'...");
        Command::new("arch-chroot")
            .arg("/mnt")
            .args(&["useradd", "-m", "-G", "wheel", "crussell"])
            .status()?;

        Ok(())
    }

    fn verify(&self) -> Result<()> {
        // Check if user exists in /mnt/etc/passwd
        let passwd = fs::read_to_string("/mnt/etc/passwd")?;
        if !passwd.contains("crussell") {
            return Err(anyhow!("User crussell not found in /etc/passwd"));
        }
        Ok(())
    }
}

// --- Step 7: Bootloader ---
pub struct InstallBootloader {
    pub disk: PathBuf,
}

impl InstallerStep for InstallBootloader {
    fn name(&self) -> &str {
        "Install Bootloader"
    }

    fn run(&self) -> Result<()> {
        info!("Installing bootctl...");
        let status = Command::new("bootctl")
            .arg("install")
            .arg("--path=/mnt/boot")
            .status()
            .context("Failed to install bootctl")?;
        if !status.success() { return Err(anyhow!("bootctl install failed")); }

        // Loader Entry
        // We use root=LABEL=ROOT because we formatted the Btrfs partition with that label.
        let entry_content = r#"title   Jig
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux.img
options root=LABEL=ROOT rootflags=subvol=@active_a rw
"#;

        let entries_dir = Path::new("/mnt/boot/loader/entries");
        fs::create_dir_all(entries_dir)?;
        fs::write(entries_dir.join("arch.conf"), entry_content)?;

        // Loader Config
        let loader_conf = "default arch.conf\ntimeout 3\nconsole-mode max\n";
        fs::write("/mnt/boot/loader/loader.conf", loader_conf)?;

        Ok(())
    }

    fn verify(&self) -> Result<()> {
        if !Path::new("/mnt/boot/loader/entries/arch.conf").exists() {
            return Err(anyhow!("Bootloader entry not found"));
        }
        Ok(())
    }
}
