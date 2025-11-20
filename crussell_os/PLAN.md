Excellent. Let's lay the foundation.

The **Subvolume Manager** is the bedrock of `jig`. If this module fails, you delete the wrong subvolume or fail to boot. It must be robust, testable, and strongly typed.

We will implement this in Rust using a **Trait-based architecture**. This allows us to write unit tests that "mock" the filesystem operations, so you can verify the A/B flipping logic without actually wiping your hard drive during development.

### 1\. The Rust Project Structure

We will structure the crate to separate concerns immediately.

```text
jig/
├── Cargo.toml
└── src/
    ├── main.rs           # CLI entry point (Clap)
    ├── storage/
    │   ├── mod.rs        # Module definition
    │   ├── btrfs.rs      # The concrete implementation (calls `btrfs` binary)
    │   └── traits.rs     # The abstract interface (allows mocking)
    ├── engine/
    │   └── update.rs     # The high-level A/B logic
    └── config.rs         # TOML handling
```

-----

### 2\. The "Subvolume Manager" Spec

Here is the specific design for the `storage` module.

#### The Types

We need rigorous types to prevent "Stringly typed" errors (passing a path where a UUID is expected).

```rust
// src/storage/types.rs

#[derive(Debug, Clone, PartialEq)]
pub struct Subvolume {
    pub id: u64,
    pub path: PathBuf,
    pub uuid: String,
    pub parent_uuid: Option<String>,
}

#[derive(Debug, Clone, PartialEq)]
pub enum TargetRoots {
    A, // @active_a
    B, // @active_b
}

impl TargetRoots {
    pub fn as_str(&self) -> &'static str {
        match self {
            TargetRoots::A => "@active_a",
            TargetRoots::B => "@active_b",
        }
    }
}
```

#### The Interface (Trait)

This is the most important part. It forces the AI agent to define *what* we want to do, separate from *how* we do it.

```rust
// src/storage/traits.rs

use anyhow::Result;
use super::types::{Subvolume, TargetRoots};

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
```

-----

### 3\. The Logic Implementation Strategy

We will instruct the AI to use `std::process::Command` to wrap the standard `btrfs` and `findmnt` CLI tools.

  * *Why not a library?* `libbtrfsutil-rs` exists but binds to C. Wrapping the CLI is often more stable for simple operations and easier to debug (you can log the exact command string).
  * *Safety:* The implementation must parse the JSON output of `btrfs subvolume list -o json /` (if available) or parse the text output robustly to ensure we don't parse whitespace incorrectly.

-----

### 4\. The Prompt for the AI Coding Agent

You can now copy-paste the following prompt to your coding agent. This initializes the project and builds the storage layer.

-----

**PROMPT:**

> You are an expert Rust Systems Engineer. We are building `jig`, an immutable system updater for Arch Linux.
>
> **Phase 1 Goal:** Initialize the project and implement the `BtrfsManager` module.
>
> **Step 1: Project Setup**
> Initialize a new Rust project named `jig`.
> Add the following dependencies to `Cargo.toml`:
>
>   - `anyhow` (Error handling)
>   - `clap` (derive feature) (CLI parsing)
>   - `serde` & `serde_json` (Parsing tool output)
>   - `log` & `env_logger` (Logging)
>   - `cmd_lib` or `std::process::Command` (For running shell commands)
>
> **Step 2: Define the Storage Layer**
> Create a module `src/storage/` with files `mod.rs`, `types.rs`, and `btrfs.rs`.
>
> 1.  **`types.rs`**: Define a struct `Subvolume` (id, path, uuid) and an enum `TargetRoots` (A, B).
> 2.  **`mod.rs`**: Define a Trait `StorageManager` that includes methods for:
>       - `get_current_root() -> Result<Subvolume>`
>       - `get_next_target() -> Result<TargetRoots>` (Logic: If current is A, return B. If B, return A).
>       - `delete_subvolume(name: &str)`
>       - `create_subvolume(name: &str)`
>       - `mount_subvolume(name: &str, path: &Path)`
> 3.  **`btrfs.rs`**: Implement this trait for a struct `BtrfsDriver`.
>       - Use `std::process::Command` to call `btrfs subvolume ...` commands.
>       - For `get_current_root`, parse `/proc/self/mountinfo` or use `findmnt` to determine which subvolume is mounted at `/`.
>       - **Crucial:** Ensure `delete_subvolume` is idempotent (doesn't fail if it already doesn't exist).
>
> **Step 3: The Main CLI**
> In `main.rs`, set up a basic Clap CLI with a subcommand `inspect` that uses your new `BtrfsDriver` to print the current root and the calculated "next" target.
>
> **Constraints:**
>
>   - Use strictly typed paths (`PathBuf`).
>   - Use `anyhow::Context` to provide helpful error messages (e.g., "Failed to detect current root subvolume").
>   - Do NOT implement the OS installation logic yet. Only the subvolume management.

-----

### Next Step (for you)

Once the agent generates this code:

1.  Run `cargo run -- inspect` on your current machine (if it's Btrfs) to see if it correctly identifies your current subvolume.
2.  **Warning:** Do not run `delete` commands on your live machine yet.

Shall we proceed with this Prompt?