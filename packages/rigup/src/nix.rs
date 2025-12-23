use crate::error::RigupError;
use miette::{IntoDiagnostic, Result};
use std::process::{Command, Stdio};

/// Detect the current system in Nix format (e.g., "x86_64-linux", "aarch64-darwin")
pub fn get_system() -> String {
    let arch = std::env::consts::ARCH;
    let os = std::env::consts::OS;

    let nix_os = match os {
        "macos" => "darwin",
        _ => os,
    };

    format!("{}-{}", arch, nix_os)
}

/// Run a nix command and return an error if it fails
pub fn run_nix_command_capture(args: Vec<&str>) -> Result<()> {
    let output = Command::new("nix").args(&args).output().into_diagnostic()?;

    if !output.status.success() {
        let code = output.status.code().unwrap_or(1);
        let stderr = String::from_utf8_lossy(&output.stderr).to_string();
        return Err(RigupError::NixCommandFailed { code, stderr }.into());
    }

    Ok(())
}

/// Run a nix command interactively, inheriting stdin/stdout/stderr
pub fn run_nix_command(args: Vec<&str>) -> Result<()> {
    let status = Command::new("nix")
        .args(&args)
        .stdin(Stdio::inherit())
        .stdout(Stdio::inherit())
        .stderr(Stdio::inherit())
        .status()
        .into_diagnostic()?;

    if !status.success() {
        let code = status.code().unwrap_or(1);
        return Err(RigupError::NixCommandFailed {
            code,
            stderr: "Nix command failed".to_string(),
        }
        .into());
    }

    Ok(())
}
