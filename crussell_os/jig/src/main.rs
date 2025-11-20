use clap::{Parser, Subcommand};
use env_logger::Env;
use log::{info, error};
use anyhow::Result;
use std::path::PathBuf;
use dialoguer::{Confirm, theme::ColorfulTheme};
use console::style;

mod installer;
use installer::{run_installer, steps};

#[derive(Parser)]
#[command(author, version, about, long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Bootstrap a new JigOS system on a block device (DESTRUCTIVE)
    Bootstrap {
        /// The target block device (e.g., /dev/vda)
        disk: PathBuf,
    },
}

fn main() -> Result<()> {
    env_logger::Builder::from_env(Env::default().default_filter_or("info")).init();

    let cli = Cli::parse();

    match &cli.command {
        Commands::Bootstrap { disk } => {
            // TUI Confirmation
            let theme = ColorfulTheme::default();
            println!("{}", style("WARNING: THIS WILL WIPE THE TARGET DISK!").bold().red());
            println!("Target: {}", style(disk.display()).yellow());
            
            if !Confirm::with_theme(&theme)
                .with_prompt("Are you sure you want to proceed?")
                .default(false)
                .interact()?
            {
                info!("Bootstrap cancelled by user.");
                return Ok(());
            }

            info!("Starting bootstrap on {:?}", disk);

            let steps = vec![
                Box::new(steps::PartitionDisk { disk: disk.clone() }) as Box<dyn installer::InstallerStep>,
                Box::new(steps::FormatPartitions { disk: disk.clone() }),
                Box::new(steps::CreateSubvolumes { disk: disk.clone() }),
                Box::new(steps::MountHierarchy { disk: disk.clone() }),
                Box::new(steps::Pacstrap),
                Box::new(steps::ConfigureSystem),
                Box::new(steps::InstallBootloader { disk: disk.clone() }),
            ];

            run_installer(steps)?;
        }
    }

    Ok(())
}
