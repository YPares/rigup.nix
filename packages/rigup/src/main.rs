mod commands;
mod display;
mod error;
mod nix;
mod types;

use clap::{Parser, Subcommand};
use commands::{
    browse_rig_docs, build_rig, enter_shell, inspect_rig, new_project, run_entrypoint, show_flake,
};
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
    /// Create a new rigup project
    New {
        /// Directory to create (defaults to current directory)
        directory: Option<String>,
        /// Template to use (defaults to "default", can be "minimal")
        #[arg(short, long, default_value = "default")]
        template: String,
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
    /// Show all riglets and rigs from a flake and its inputs
    Show {
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
    /// Inspect a specific rig's structure and configuration
    Inspect {
        /// Flake reference in the form `<flake>#<rig>` (defaults to `.#default`)
        ///
        /// Current repo must use `.#` prefix. Examples: `.#myrig`, `github:user/repo`, `github:user/repo#myrig`
        flake_ref: Option<String>,
        /// Show all details
        ///
        /// Adds keywords, tools, when-to-use for riglets
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
    /// Browse a rig's documentation with $EDITOR (or specified program)
    Browse {
        /// Flake reference in the form `<flake>#<rig>` (defaults to `.#default`)
        ///
        /// Current repo must use `.#` prefix. Examples: `.#myrig`, `github:user/repo`, `github:user/repo#myrig`
        flake_ref: Option<String>,
        /// Program to open documentation with (defaults to $EDITOR)
        #[arg(short, long)]
        with_: Option<String>,
        /// Disable auto-staging of rigup.local.toml
        #[arg(long)]
        no_stage: bool,
    },
}

fn main() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Commands::Browse {
            flake_ref,
            with_,
            no_stage,
        } => {
            browse_rig_docs(with_, flake_ref, no_stage)?;
        }
        Commands::New {
            directory,
            template,
        } => {
            new_project(directory, template)?;
        }
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
        Commands::Show {
            flake,
            with_inputs,
            no_pager,
            detailed,
            no_descriptions,
            no_stage,
        } => {
            show_flake(
                flake,
                with_inputs,
                no_pager,
                detailed,
                no_descriptions,
                no_stage,
            )?;
        }
        Commands::Inspect {
            flake_ref,
            no_pager,
            detailed,
            no_descriptions,
            no_stage,
        } => {
            inspect_rig(flake_ref, no_pager, detailed, no_descriptions, no_stage)?;
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
