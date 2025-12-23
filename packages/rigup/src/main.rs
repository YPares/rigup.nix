mod commands;
mod error;
mod nix;
mod types;

use clap::{Parser, Subcommand};
use commands::{build_rig, enter_shell, list_inputs};
use miette::Result;

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
        /// Flake reference in the form <flake>#<rig> (defaults to ".#default")
        /// Current repo must use ".#" prefix. Examples: ".#myrig", "github:user/repo", "github:user/repo#myrig"
        flake_ref: Option<String>,
    },
    /// Enter a development shell for a rig
    Shell {
        /// Flake reference in the form <flake>#<rig> (defaults to ".#default")
        /// Current repo must use ".#" prefix. Examples: ".#myrig", "github:user/repo", "github:user/repo#myrig"
        flake_ref: Option<String>,
        /// Command to run in the shell
        #[arg(short, long, num_args = 1.., allow_hyphen_values = true)]
        command: Vec<String>,
    },
    /// List all flake inputs that expose riglets
    List {
        /// Flake to inspect (defaults to ".")
        /// Examples: ".", "github:user/repo"
        flake: Option<String>,
    },
}

fn main() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Commands::Build { flake_ref } => {
            build_rig(flake_ref)?;
        }
        Commands::Shell { flake_ref, command } => {
            enter_shell(flake_ref, command)?;
        }
        Commands::List { flake } => {
            list_inputs(flake)?;
        }
    }

    Ok(())
}
