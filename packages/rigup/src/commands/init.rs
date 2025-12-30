use crate::error::RigupError;
use miette::{IntoDiagnostic, Result};
use owo_colors::OwoColorize;
use std::env;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};

/// Run a command interactively with inherited stdio and check exit status
fn run_command(program: &str, args: &[&str], cwd: &Path) -> Result<()> {
    let status = Command::new(program)
        .args(args)
        .current_dir(cwd)
        .stdin(Stdio::inherit())
        .stdout(Stdio::inherit())
        .stderr(Stdio::inherit())
        .status()
        .into_diagnostic()?;

    if !status.success() {
        Err(RigupError::NixCommandFailed {
            code: status.code().unwrap_or(1),
            stderr: format!("{} {} failed", program, args.join(" ")),
        }
        .into())
    } else {
        Ok(())
    }
}

/// Initialize a new rigup project
pub fn init_project(directory: Option<String>, template: String) -> Result<()> {
    // Determine target directory
    let target_dir = if let Some(dir) = directory {
        PathBuf::from(&dir)
    } else {
        env::current_dir().into_diagnostic()?
    };

    // Create directory if it doesn't exist
    if !target_dir.exists() {
        eprintln!(
            "📁 Creating directory {}...",
            target_dir.display().to_string().cyan()
        );
        std::fs::create_dir_all(&target_dir).into_diagnostic()?;
    }

    // Check if directory is empty (warn if not)
    if target_dir.read_dir().into_diagnostic()?.next().is_some() {
        eprintln!(
            "⚠️  Directory {} is not empty. Files may be overwritten.",
            target_dir.display().yellow(),
        );
    }

    // Initialize git repository
    eprintln!("🔧 Initializing git repository...");
    run_command("git", &["init"], &target_dir)?;

    // Initialize nix flake from template
    let template_ref = format!("github:YPares/rigup.nix#{}", template);
    eprintln!("📦 Initializing from template {}...", template_ref.cyan());
    run_command("nix", &["flake", "init", "-t", &template_ref], &target_dir)?;

    eprintln!("✨ Staging files...");
    run_command("git", &["add", "."], &target_dir)?;

    // Run nix flake check
    eprintln!("🔍 Running flake check...");
    run_command(
        "nix",
        &["flake", "check", "--quiet", "--quiet"],
        &target_dir,
    )?;

    eprintln!("✅ Done");
    Ok(())
}
