mod commands;
mod error;
mod nix;
mod rig_context;
mod types;

use clap::{Parser, Subcommand};
use commands::{build_rig, enter_shell, list_inputs};
use miette::Result;
use rig_context::{get_last_used_rig, save_last_used_rig};

#[derive(Parser)]
#[command(name = "rigup")]
#[command(about = "CLI tool for managing rigup rigs", long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Build a rig's home directory
    Build {
        /// Name of the rig to build (defaults to last used rig, or "default" if none)
        rig: Option<String>,
    },
    /// Enter a development shell for a rig
    Shell {
        /// Name of the rig (defaults to last used rig, or "default" if none)
        rig: Option<String>,
        /// Command to run in the shell
        #[arg(short, long, num_args = 1.., allow_hyphen_values = true)]
        command: Vec<String>,
    },
    /// List various rigup resources
    List {
        #[command(subcommand)]
        resource: ListCommands,
    },
}

#[derive(Subcommand)]
enum ListCommands {
    /// List all flake inputs that expose riglets
    Inputs,
}

fn main() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Commands::Build { rig } => {
            let resolved_rig = match rig {
                Some(name) => name,
                None => get_last_used_rig()?,
            };
            build_rig(&resolved_rig)?;
            save_last_used_rig(&resolved_rig)?;
        }
        Commands::Shell { rig, command } => {
            let resolved_rig = match rig {
                Some(name) => name,
                None => get_last_used_rig()?,
            };
            enter_shell(&resolved_rig, command)?;
            save_last_used_rig(&resolved_rig)?;
        }
        Commands::List { resource } => match resource {
            ListCommands::Inputs => list_inputs()?,
        },
    }

    Ok(())
}
