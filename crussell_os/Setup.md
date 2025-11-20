This is a **power move**. Writing your own installer in Rust effectively makes you the maintainer of your own Linux distribution ("RussellOS"). It creates a perfect feedback loop: if the installer works, your system is reproducible by definition.

Since you have a build machine, we can iterate fast.

Here is the prompt for the AI coding agent. I have designed it to use `sfdisk` (scriptable fdisk) instead of `fdisk` because it is much safer for automation. I also explicitly included the **Bootloader Setup** step that we missed in the manual attempt.

-----

### 🤖 Prompt for the AI Coding Agent

**Context:**
We are building `jig`, a Rust-based system manager for an immutable Arch Linux setup. We currently have the `storage` module skeleton.

**The Task:**
Implement a new subcommand: `bootstrap`.
This command will take a block device (e.g., `/dev/vda`), wipe it, and turn it into a fully bootable "jigOS" system.

**Requirements & Logic Flow:**

1.  **CLI Argument:**
    Add `Bootstrap { disk: PathBuf }` to the Clap enum in `main.rs`.

2.  **Module `src/installer.rs`:**
    Create a new module to handle the installation logic. It should perform the following steps sequentially. Use `std::process::Command` and `anyhow::Context` for error reporting.

      * **Step 1: Partitioning (The Wiping):**

          * Use `sfdisk` to script the partition table creation on the target disk.
          * **Layout:**
              * Partition 1: 1GB, Type: `C12A7328-F81F-11D2-BA4B-00A0C93EC93B` (EFI System).
              * Partition 2: Remaining space, Type: `0FC63DAF-8483-4772-8E79-3D69D8477DE4` (Linux Filesystem).
          * *Hint:* You can feed a string into `sfdisk` via stdin: `label: gpt, size=1G type=UEFI, type=linux`.

      * **Step 2: Formatting:**

          * Format P1 with `mkfs.fat -F 32`.
          * Format P2 with `mkfs.btrfs -L jigos`.

      * **Step 3: Subvolumes:**

          * Mount P2 to a temporary location (e.g., `/tmp/jig-install`).
          * Create the subvolumes: `@active_a`, `@active_b`, `@snapshots`, `@var_log`, `@var_cache`, `@home_root`, `@home_vault`.
          * Unmount.

      * **Step 4: Mounting the Hierarchy:**

          * Mount `@active_a` to `/mnt`.
          * Create directories: `/mnt/efi`, `/mnt/home`, `/mnt/var/log`, `/mnt/var/cache`, `/mnt/snapshots`, `/mnt/mnt/vault`.
          * Mount the persistent subvolumes into their respective places.
          * Mount P1 to `/mnt/efi`.

      * **Step 5: The Base Install (Pacstrap):**

          * Run `pacstrap /mnt base linux linux-firmware intel-ucode btrfs-progs systemd networkmanager vim git openssh sudo`.

      * **Step 6: System Configuration (Crucial):**

          * **Fstab:** Run `genfstab -U /mnt >> /mnt/etc/fstab` (We will make this more "pure" later, use this for now).
          * **Timezone:** Link `/usr/share/zoneinfo/UTC` to `/mnt/etc/localtime`.
          * **Locale:** Write `en_US.UTF-8 UTF-8` to `/mnt/etc/locale.gen` and run `arch-chroot /mnt locale-gen`.
          * **Hostname:** Write "jig" to `/mnt/etc/hostname`.
          * **User:** `arch-chroot /mnt useradd -m -G wheel crussell`. (Don't set a password yet, or set a default like 'changeme').

      * **Step 7: The Bootloader (The Fix):**

          * Run `bootctl install --path=/mnt/efi`.
          * **Loader Entry:** Create `/mnt/efi/loader/entries/arch.conf` with:
            ```text
            title   Jig
            linux   /vmlinuz-linux
            initrd  /intel-ucode.img
            initrd  /initramfs-linux.img
            options root="PARTLABEL=primary" rootflags=subvol=@active_a rw
            ```
            *(Note: To be safe, use the UUID of P2 if possible, but for this specific task, use the device path or `PARTUUID` logic if you can script it. If complex, rely on `/dev/disk/by-partlabel` or similar).*
          * **Loader Config:** Update `/mnt/efi/loader/loader.conf` to set `default arch.conf`.

**Implementation Note:**
Be extremely verbose with logging. We need to see exactly which step fails (e.g., "Failed to mount EFI partition").

-----

### 📝 How to Test This

Once the agent gives you the code and you compile it on your helper machine:

1.  **SCP:** `scp target/release/jig root@<VM_IP>:/usr/local/bin/`
2.  **Run:** `./jig bootstrap /dev/sda` (inside the VM).
3.  **Watch:** It should print the logs as it partitions, formats, and installs.
4.  **Reboot:** If it works, you'll reboot straight into a login prompt.