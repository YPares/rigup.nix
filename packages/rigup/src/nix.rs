use crate::error::RigupError;
use miette::{IntoDiagnostic, Result};
use owo_colors::OwoColorize;
use serde_json::Value;
use std::io::Read;
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

    let metadata: Value = serde_json::from_slice(&output.stdout).into_diagnostic()?;

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

/// Parse a flake reference like "<flake>#<rig>"
/// Returns (flake_path, rig_name)
///
/// To avoid ambiguity (following nix flake conventions):
/// - If no `#` is present, treat as flake reference with default rig
/// - Current repo MUST use `.#` prefix explicitly
///
/// Examples:
/// - None -> ".#default"
/// - ".#myrig" -> current repo, myrig
/// - "github:foo/bar" -> "github:foo/bar#default"
/// - "github:foo/bar#myrig" -> "github:foo/bar#myrig"
/// - "example-rig" -> "example-rig#default" (flake reference, NOT rig name!)
pub fn parse_flake_ref(flake_ref: Option<&str>) -> Result<(String, String)> {
    let ref_str = flake_ref.unwrap_or(".#default");

    if let Some((flake, rig)) = ref_str.split_once('#') {
        // Explicit flake#rig format
        Ok((flake.to_string(), rig.to_string()))
    } else {
        // No # means it's a flake reference, default to #default
        Ok((ref_str.to_string(), "default".to_string()))
    }
}

/// Ensure rigup.local.toml is staged if it exists in the given directory
fn ensure_local_toml_staged(flake_root: &PathBuf, no_stage: bool) -> Result<()> {
    if no_stage {
        return Ok(());
    }

    let local_toml = flake_root.join("rigup.local.toml");
    if local_toml.exists() {
        eprintln!(
            "{} detected. Staging it in git so is included in the flake contents.",
            "rigup.local.toml".yellow()
        );
        // Use git add -f to stage it even though it's gitignored
        // This allows git+file: references to see it without copying the whole repo
        let _ = Command::new("git")
            .args(&["add", "-f", "rigup.local.toml"])
            .current_dir(flake_root)
            .output()
            .into_diagnostic()?;
        // Ignore errors - if git add fails, the subsequent nix command will fail with a clear error
    }
    Ok(())
}

/// Resolve a flake path, converting "." to git+file: reference and ensuring rigup.local.toml is staged
pub fn resolve_flake_path(flake_path: &str, no_stage: bool) -> Result<String> {
    if flake_path == "." {
        let flake_root = get_flake_root()?;
        ensure_local_toml_staged(&flake_root, no_stage)?;
        Ok(format!("git+file:{}", flake_root.display()))
    } else {
        Ok(flake_path.to_string())
    }
}

/// Build a complete flake reference for a rig component
/// Takes parsed flake path and rig name, returns full reference
pub fn build_flake_ref(
    flake_path: &str,
    rig: &str,
    system: &str,
    component: &str,
    no_stage: bool,
) -> Result<String> {
    let resolved_path = resolve_flake_path(flake_path, no_stage)?;
    Ok(format!(
        "{}#rigs.{}.{}.{}",
        resolved_path, system, rig, component
    ))
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

/// Run a nix eval command that returns JSON, capturing stdout but showing stderr
/// This is useful for commands that output JSON while showing build progress
pub fn run_nix_eval_json(eval_expr: &str) -> Result<Value> {
    let mut child = Command::new("nix")
        .args(&["eval", "--impure", "--expr", eval_expr, "--json"])
        .stdout(Stdio::piped())
        .stderr(Stdio::inherit())
        .spawn()
        .into_diagnostic()?;

    // Read stdout (contains JSON result)
    let mut stdout = Vec::new();
    child
        .stdout
        .take()
        .expect("Failed to capture stdout")
        .read_to_end(&mut stdout)
        .into_diagnostic()?;

    // Wait for process to complete
    let status = child.wait().into_diagnostic()?;

    if !status.success() {
        let code = status.code().unwrap_or(1);
        return Err(RigupError::NixCommandFailed {
            code,
            stderr: "See error output above".to_string(),
        }
        .into());
    }

    // Parse JSON result
    serde_json::from_slice(&stdout).into_diagnostic()
}
