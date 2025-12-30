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
        /// Flake reference in the form `<flake>#<rig>` (defaults to `.#default`)
        ///
        /// Current repo must use `.#` prefix. Examples: `.#myrig`, `github:user/repo`, `github:user/repo#myrig`
        flake_ref: Option<String>,
        /// Disable auto-staging of rigup.local.toml
        #[arg(long)]
        no_stage: bool,
    },
    /// Enter a development shell for a rig
    Shell {
        /// Flake reference in the form `<flake>#<rig>` (defaults to `.#default`)
        ///
        /// Current repo must use `.#` prefix. Examples: `.#myrig`, `github:user/repo`, `github:user/repo#myrig`
        flake_ref: Option<String>,
        /// Command to run in the shell
        #[arg(short, long, num_args = 1.., allow_hyphen_values = true)]
        command: Vec<String>,
        /// Disable auto-staging of rigup.local.toml
        #[arg(long)]
        no_stage: bool,
    },
    /// List all riglets and rigs from a flake and its inputs
    List {
        /// Flake to inspect (defaults to `.`)
        ///
        /// Examples: `.`, `github:user/repo[/branch]`, `git+file:/abs/path/to/local/clone`
        flake: Option<String>,
        /// Include flake inputs
        ///
        /// By default only `self`, the given flake, is shown. This will also list the rigs and riglets provided by its own input flakes
        #[arg(short = 'i', long)]
        with_inputs: bool,
        /// Show all details
        ///
        /// Adds keywords, tools, when-to-use for riglets and riglet list for rigs
        #[arg(short, long)]
        detailed: bool,
        /// Hide riglet descriptions
        #[arg(short = 'D', long)]
        no_descriptions: bool,
        /// Disable paging through less
        #[arg(short = 'P', long)]
        no_pager: bool,
        /// Disable auto-staging of rigup.local.toml
        #[arg(long)]
        no_stage: bool,
    },
    /// Run a rig's entrypoint
    Run {
        /// Flake reference in the form `<flake>#<rig>` (defaults to `.#default`)
        ///
        /// Current repo must use `.#` prefix. Examples: `.#myrig`, `github:user/repo[/branch]`, `github:user/repo#myrig`
        flake_ref: Option<String>,
        /// Arguments to forward to the entrypoint
        #[arg(trailing_var_arg = true, allow_hyphen_values = true)]
        args: Vec<String>,
        /// Disable auto-staging of rigup.local.toml
        #[arg(long)]
        no_stage: bool,
    },
}

fn main() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Commands::Build {
            flake_ref,
            no_stage,
        } => {
            build_rig(flake_ref, no_stage)?;
        }
        Commands::Shell {
            flake_ref,
            command,
            no_stage,
        } => {
            enter_shell(flake_ref, command, no_stage)?;
        }
        Commands::List {
            flake,
            with_inputs,
            no_pager,
            detailed,
            no_descriptions,
            no_stage,
        } => {
            list_inputs(
                flake,
                with_inputs,
                no_pager,
                detailed,
                no_descriptions,
                no_stage,
            )?;
        }
        Commands::Run {
            flake_ref,
            args,
            no_stage,
        } => {
            run_entrypoint(flake_ref, &args, no_stage)?;
        }
    }

    Ok(())
}
