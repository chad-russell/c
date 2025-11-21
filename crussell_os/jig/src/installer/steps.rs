// steps.rs
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
        "Partition Disk (GPT 1GB EFI + Rest Btrfs)"
    }

    fn run(&self) -> Result<()> {
        info!("Partitioning disk: {:?}", self.disk);
        
        // Standard GPT Layout
        // 1. EFI System (1GB)
        // 2. Linux Filesystem (Remainder)
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

        // Wait for kernel partition table update
        std::thread::sleep(std::time::Duration::from_secs(2));
        Ok(())
    }

    fn verify(&self) -> Result<()> {
        let disk_str = self.disk.to_string_lossy();
        // Simple heuristic for NVMe vs sdX naming
        let p2 = if disk_str.contains("nvme") { format!("{}p2", disk_str) } else { format!("{}2", disk_str) };

        if !Path::new(&p2).exists() {
            return Err(anyhow!("Partition 2 not found after sfdisk"));
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
        "Format Partitions (FAT32 & Btrfs)"
    }

    fn run(&self) -> Result<()> {
        let disk_str = self.disk.to_string_lossy();
        let p1 = if disk_str.contains("nvme") { format!("{}p1", disk_str) } else { format!("{}1", disk_str) };
        let p2 = if disk_str.contains("nvme") { format!("{}p2", disk_str) } else { format!("{}2", disk_str) };

        info!("Formatting EFI partition: {}", p1);
        let status = Command::new("mkfs.fat")
            .arg("-F32")
            .arg("-n").arg("EFI")
            .arg(&p1)
            .status()?;
        if !status.success() { return Err(anyhow!("mkfs.fat failed")); }

        info!("Formatting Root partition (Btrfs Label: ARCH): {}", p2);
        let status = Command::new("mkfs.btrfs")
            .arg("-f")
            .arg("-L").arg("ARCH") // Label used for fstab/bootloader mounting
            .arg(&p2)
            .status()?;
        if !status.success() { return Err(anyhow!("mkfs.btrfs failed")); }

        Ok(())
    }

    fn verify(&self) -> Result<()> { Ok(()) }
}

// --- Step 3: Subvolumes ---
pub struct CreateSubvolumes {
    pub disk: PathBuf,
}

impl InstallerStep for CreateSubvolumes {
    fn name(&self) -> &str {
        "Create Subvolumes (Flat Snapper Layout)"
    }

    fn run(&self) -> Result<()> {
        let disk_str = self.disk.to_string_lossy();
        let p2 = if disk_str.contains("nvme") { format!("{}p2", disk_str) } else { format!("{}2", disk_str) };
        let mount_point = Path::new("/tmp/jig-install-subvols");

        if !mount_point.exists() { fs::create_dir_all(mount_point)?; }

        // Mount root temporarily
        let status = Command::new("mount").arg(&p2).arg(mount_point).status()?;
        if !status.success() { return Err(anyhow!("Failed to mount root for subvol creation")); }

        // Snapper/Flat Layout
        let subvols = vec![
            "@",            // Root
            "@home",        // User Data
            "@snapshots",   // Snapper snapshots
            "@log",         // /var/log (keep logs on rollback)
            "@cache"        // /var/cache (keep pacman cache on rollback)
        ];

        for subvol in subvols {
            info!("Creating subvolume: {}", subvol);
            let status = Command::new("btrfs")
                .args(&["subvolume", "create"])
                .arg(mount_point.join(subvol))
                .status()?;
            if !status.success() { 
                let _ = Command::new("umount").arg(mount_point).status();
                return Err(anyhow!("Failed to create subvolume {}", subvol)); 
            }
        }

        Command::new("umount").arg(mount_point).status()?;
        Ok(())
    }

    fn verify(&self) -> Result<()> { Ok(()) }
}

// --- Step 4: Mounting Hierarchy ---
pub struct MountHierarchy {
    pub disk: PathBuf,
}

impl InstallerStep for MountHierarchy {
    fn name(&self) -> &str {
        "Mount Hierarchy (With Optimization Flags)"
    }

    fn run(&self) -> Result<()> {
        let disk_str = self.disk.to_string_lossy();
        let p1 = if disk_str.contains("nvme") { format!("{}p1", disk_str) } else { format!("{}1", disk_str) };
        let p2 = if disk_str.contains("nvme") { format!("{}p2", disk_str) } else { format!("{}2", disk_str) };
        let target = Path::new("/mnt");
        
        // Common optimization flags
        let flags = "noatime,compress=zstd,discard=async";

        // 1. Mount Root (@) to /mnt
        info!("Mounting @ to /mnt");
        let status = Command::new("mount")
            .arg("-o").arg(format!("subvol=@,{}", flags))
            .arg(&p2)
            .arg(target)
            .status()?;
        if !status.success() { return Err(anyhow!("Failed to mount @")); }

        // 2. Create Mount Points
        let dirs = vec!["boot", "home", "var/log", "var/cache", ".snapshots"];
        for dir in dirs { fs::create_dir_all(target.join(dir))?; }

        // 3. Mount Subvolumes
        let mounts = vec![
            ("@home", "home"),
            ("@snapshots", ".snapshots"),
            ("@log", "var/log"),
            ("@cache", "var/cache"),
        ];

        for (subvol, dir) in mounts {
            info!("Mounting {} to {}", subvol, dir);
            let status = Command::new("mount")
                .arg("-o").arg(format!("subvol={},{}", subvol, flags))
                .arg(&p2)
                .arg(target.join(dir))
                .status()?;
            if !status.success() { return Err(anyhow!("Failed to mount {}", subvol)); }
        }

        // 4. Mount EFI to /boot (Directly for systemd-boot)
        info!("Mounting EFI partition to /boot");
        let status = Command::new("mount")
            .arg(&p1)
            .arg(target.join("boot"))
            .status()?;
        if !status.success() { return Err(anyhow!("Failed to mount EFI to /boot")); }

        Ok(())
    }

    fn verify(&self) -> Result<()> {
        if !Path::new("/mnt/boot").exists() { return Err(anyhow!("/mnt/boot does not exist")); }
        Ok(())
    }
}

// --- Step 5: Pacstrap ---
pub struct Pacstrap;

impl InstallerStep for Pacstrap {
    fn name(&self) -> &str {
        "Pacstrap Base System (Intel/ThinkPad)"
    }

    fn run(&self) -> Result<()> {
        info!("Running pacstrap...");
        // Added: mesa, vulkan-intel, sof-firmware (Audio), base-devel (for AUR later)
        let packages = vec![
            "base", "linux", "linux-firmware", "base-devel",
            "intel-ucode", "mesa", "vulkan-intel", "sof-firmware",
            "btrfs-progs", "systemd", "networkmanager", 
            "vim", "nano", "git", "openssh", "sudo", "man-db"
        ];

        let status = Command::new("pacstrap")
            .arg("-K") // Initialize keyring inside chroot
            .arg("/mnt")
            .args(&packages)
            .status()
            .context("Failed to run pacstrap")?;
        
        if !status.success() { return Err(anyhow!("Pacstrap failed")); }
        Ok(())
    }

    fn verify(&self) -> Result<()> {
        if !Path::new("/mnt/bin/bash").exists() { return Err(anyhow!("Base system not found")); }
        Ok(())
    }
}

// --- Step 6: System Configuration ---
pub struct ConfigureSystem;

impl InstallerStep for ConfigureSystem {
    fn name(&self) -> &str {
        "Configure System (Fstab, User, Swapfile)"
    }

    fn run(&self) -> Result<()> {
        // 1. Swapfile Creation (The Correct NoCoW Way)
        info!("Creating Btrfs Swapfile (8GB)...");
        let swapfile = Path::new("/mnt/swapfile");
        // truncate -s 0
        Command::new("truncate").args(&["-s", "0"]).arg(swapfile).status()?;
        // chattr +C (NoCoW)
        Command::new("chattr").args(&["+C"]).arg(swapfile).status()?;
        // dd
        Command::new("dd").args(&["if=/dev/zero", "of=/mnt/swapfile", "bs=1M", "count=8192", "status=progress"]).status()?;
        // chmod & mkswap
        Command::new("chmod").args(&["0600"]).arg(swapfile).status()?;
        Command::new("mkswap").arg(swapfile).status()?;


        // 2. Genfstab
        info!("Generating fstab...");
        let output = Command::new("genfstab").arg("-U").arg("/mnt").output()?;
        let mut fstab = fs::OpenOptions::new().append(true).open("/mnt/etc/fstab")?;
        fstab.write_all(&output.stdout)?;
        // Add swapfile to fstab
        writeln!(fstab, "/swapfile none swap defaults 0 0")?;


        // 3. Timezone & Locale
        info!("Configuring Time & Locale...");
        Command::new("arch-chroot").arg("/mnt").args(&["ln", "-sf", "/usr/share/zoneinfo/America/New_York", "/etc/localtime"]).status()?;
        Command::new("arch-chroot").arg("/mnt").args(&["hwclock", "--systohc"]).status()?;
        
        let mut locale_gen = fs::OpenOptions::new().append(true).open("/mnt/etc/locale.gen")?;
        writeln!(locale_gen, "en_US.UTF-8 UTF-8")?;
        Command::new("arch-chroot").arg("/mnt").arg("locale-gen").status()?;
        fs::write("/mnt/etc/locale.conf", "LANG=en_US.UTF-8")?;


        // 4. Hostname & Network
        info!("Setting hostname...");
        fs::write("/mnt/etc/hostname", "arch-thinkpad")?;
        fs::write("/mnt/etc/hosts", "127.0.0.1\tlocalhost\n::1\tlocalhost\n127.0.1.1\tarch-thinkpad.localdomain\tarch-thinkpad\n")?;


        // 5. User & Sudo
        info!("Creating user 'crussell'...");
        Command::new("arch-chroot").arg("/mnt").args(&["useradd", "-m", "-G", "wheel", "-s", "/bin/bash", "crussell"]).status()?;
        
        // Set password
        info!("Setting default password...");
        let mut child = Command::new("arch-chroot").arg("/mnt").arg("chpasswd").stdin(Stdio::piped()).spawn()?;
        if let Some(mut stdin) = child.stdin.take() {
            stdin.write_all(b"crussell:changeme").context("Failed to write password")?;
        }
        child.wait()?;

        // Enable Sudo for Wheel
        // We use sed to uncomment the line
        Command::new("sed").arg("-i").arg("s/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/").arg("/mnt/etc/sudoers").status()?;


        // 6. Enable Services
        Command::new("arch-chroot").arg("/mnt").args(&["systemctl", "enable", "NetworkManager"]).status()?;

        Ok(())
    }

    fn verify(&self) -> Result<()> {
        let passwd = fs::read_to_string("/mnt/etc/passwd")?;
        if !passwd.contains("crussell") { return Err(anyhow!("User crussell not found")); }
        Ok(())
    }
}

// --- Step 7: Bootloader ---
pub struct InstallBootloader;

impl InstallerStep for InstallBootloader {
    fn name(&self) -> &str {
        "Install Bootloader (systemd-boot)"
    }

    fn run(&self) -> Result<()> {
        info!("Installing systemd-boot...");
        // Bootctl install
        let status = Command::new("bootctl")
            .arg("install")
            .arg("--path=/mnt/boot")
            .status()?;
        if !status.success() { return Err(anyhow!("bootctl install failed")); }

        // Loader Entry
        // Using root=LABEL=ARCH to match mkfs.btrfs label
        // Using rootflags=subvol=@ to target the root subvolume
        let entry_content = r#"title   Arch Linux
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux.img
options root=LABEL=ARCH rootflags=subvol=@ rw quiet
"#;

        let entries_dir = Path::new("/mnt/boot/loader/entries");
        if !entries_dir.exists() { fs::create_dir_all(entries_dir)?; }
        fs::write(entries_dir.join("arch.conf"), entry_content)?;

        // Loader Config
        let loader_conf = "default arch.conf\ntimeout 3\nconsole-mode max\neditor no\n";
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