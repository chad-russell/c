use anyhow::{Result, Context};
use log::{info, error};
use console::style;

pub mod steps;

pub trait InstallerStep {
    fn name(&self) -> &str;
    fn run(&self) -> Result<()>;
    fn verify(&self) -> Result<()>;
}

pub fn run_installer(steps: Vec<Box<dyn InstallerStep>>) -> Result<()> {
    info!("{}", style("Starting Jig Bootstrap Installer").bold().green());

    for step in steps {
        let name = step.name();
        info!("{}", style(format!("Step: {}", name)).bold().cyan());

        match step.run() {
            Ok(_) => {
                info!("  {} completed successfully.", name);
            }
            Err(e) => {
                error!("  {} failed: {}", name, e);
                return Err(e.context(format!("Step '{}' failed", name)));
            }
        }

        info!("  Verifying {}...", name);
        match step.verify() {
            Ok(_) => {
                info!("  {} verification passed.", name);
            }
            Err(e) => {
                error!("  {} verification failed: {}", name, e);
                return Err(e.context(format!("Step '{}' verification failed", name)));
            }
        }
    }

    info!("{}", style("Installation completed successfully!").bold().green());
    Ok(())
}
