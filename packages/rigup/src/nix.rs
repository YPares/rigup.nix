use crate::error::RigupError;
use miette::{IntoDiagnostic, Result};
use serde_json::Value;
use std::path::PathBuf;
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

/// Find the flake root directory by calling `nix flake metadata --json`
pub fn get_flake_root() -> Result<PathBuf> {
    let output = Command::new("nix")
        .args(&["flake", "metadata", "--json"])
        .output()
        .into_diagnostic()?;

    if !output.status.success() {
        let code = output.status.code().unwrap_or(1);
        let stderr = String::from_utf8_lossy(&output.stderr).to_string();
        return Err(RigupError::NixCommandFailed { code, stderr }.into());
    }

    let metadata: Value = serde_json::from_slice(&output.stdout)
        .into_diagnostic()?;

    let resolved_url = metadata
        .get("resolvedUrl")
        .and_then(|v| v.as_str())
        .ok_or_else(|| miette::miette!("Failed to get resolvedUrl from flake metadata"))?;

    // resolvedUrl is in the form "git+file:///path" or "path:/path"
    // We need to extract just the path part
    let path_str = resolved_url
        .strip_prefix("git+file://")
        .or_else(|| resolved_url.strip_prefix("path:"))
        .unwrap_or(resolved_url);

    Ok(PathBuf::from(path_str))
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
