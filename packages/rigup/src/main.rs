mod commands;
mod error;
mod nix;
mod types;

use clap::{Parser, Subcommand};
use commands::{build_rig, enter_shell, list_inputs, run_entrypoint};
use miette::Result;

#[derive(Parser)]
#[command(name = "rigup")]
#[command(about = "Build your AI agent's rig\nParameterizable skills and tools, packaged together via Nix modules", long_about = None)]
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
    /// List all riglets and rigs from a flake and its inputs
    List {
        /// Flake to inspect (defaults to ".")
        /// Examples: ".", "github:user/repo"
        flake: Option<String>,
        /// Include flake inputs (by default only shows "self")
        #[arg(short, long)]
        inputs: bool,
    },
    /// Run a rig's entrypoint
    Run {
        /// Flake reference in the form <flake>#<rig> (defaults to ".#default")
        /// Current repo must use ".#" prefix. Examples: ".#myrig", "github:user/repo", "github:user/repo#myrig"
        flake_ref: Option<String>,
        /// Arguments to forward to the entrypoint
        #[arg(trailing_var_arg = true, allow_hyphen_values = true)]
        args: Vec<String>,
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
        Commands::List { flake, inputs } => {
            list_inputs(flake, inputs)?;
        }
        Commands::Run { flake_ref, args } => {
            run_entrypoint(flake_ref, &args)?;
        }
    }

    Ok(())
}
