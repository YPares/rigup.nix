use crate::error::RigupError;
use miette::{IntoDiagnostic, Result};
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

/// Find the project root directory by looking for rigup.toml
/// Walks up from current directory until finding rigup.toml or reaching filesystem root
pub fn find_project_root() -> Result<PathBuf> {
    let mut current = std::env::current_dir().into_diagnostic()?;

    loop {
        let rigup_toml = current.join("rigup.toml");
        if rigup_toml.exists() {
            return Ok(current);
        }

        // Try to go to parent directory
        if let Some(parent) = current.parent() {
            current = parent.to_path_buf();
        } else {
            // Reached filesystem root without finding rigup.toml
            return Err(miette::miette!(
                "Could not find rigup.toml in current directory or any parent directory"
            ));
        }
    }
}

/// Find rigup.local.toml if it exists
/// Returns the absolute path to the file if found
pub fn find_local_config() -> Result<Option<PathBuf>> {
    // Find project root
    let project_root = match find_project_root() {
        Ok(root) => root,
        Err(_) => {
            // No project root found, no local overrides
            return Ok(None);
        }
    };

    let local_toml_path = project_root.join("rigup.local.toml");

    if local_toml_path.exists() {
        Ok(Some(local_toml_path))
    } else {
        Ok(None)
    }
}

/// Helper struct for managing local configuration overrides
pub struct LocalOverrides {
    /// Path to the local config file (for setting env var)
    local_path: Option<PathBuf>,
}

impl LocalOverrides {
    /// Apply local overrides to a vec of args (for run_nix_command)
    /// Sets env var and adds --impure flag
    pub fn apply_to_args<'a>(&'a self, args: &mut Vec<&'a str>) {
        if let Some(ref local_path) = self.local_path {
            // Set environment variable for Nix to read
            std::env::set_var("RIGUP_LOCAL_TOML", local_path);
            // Add --impure flag to enable getFlake
            args.push("--impure");
        }
    }

    /// Apply local overrides to a Command (for direct Command usage)
    /// Sets env var and adds --impure flag
    pub fn apply_to_command(&self, cmd: &mut Command) {
        if let Some(ref local_path) = self.local_path {
            // Set environment variable for Nix to read
            cmd.env("RIGUP_LOCAL_TOML", local_path);
            // Add --impure flag to enable getFlake
            cmd.arg("--impure");
        }
    }
}

/// Prepare local configuration overrides in a form ready to apply to nix commands
/// This is the main entry point that commands should use
pub fn prepare_local_overrides() -> Result<LocalOverrides> {
    let local_path = find_local_config()?;

    Ok(LocalOverrides { local_path })
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

/// Build a complete flake reference for a rig component
/// Takes parsed flake path and rig name, returns full reference
pub fn build_flake_ref(
    flake_path: &str,
    rig: &str,
    system: &str,
    component: &str,
) -> Result<String> {
    Ok(format!(
        "{}#rigs.{}.{}.{}",
        flake_path, system, rig, component
    ))
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

/// Run a nix eval command that returns JSON, capturing stdout but showing stderr
/// This is useful for commands that output JSON while showing build progress
/// Accepts local overrides to apply --impure and env var
/// The impure parameter forces --impure mode even without local overrides (needed for builtins.getFlake)
pub fn run_nix_eval_json(
    eval_expr: &str,
    local_overrides: &LocalOverrides,
    impure: bool,
) -> Result<Value> {
    let mut cmd = Command::new("nix");
    cmd.args(&["eval", "--expr", eval_expr, "--json"]);

    // Apply local overrides
    local_overrides.apply_to_command(&mut cmd);

    // If impure mode is requested and not already added by local overrides, add --impure flag
    if impure && local_overrides.local_path.is_none() {
        cmd.arg("--impure");
    }

    cmd.stdout(Stdio::piped()).stderr(Stdio::inherit());

    let mut child = cmd.spawn().into_diagnostic()?;

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
