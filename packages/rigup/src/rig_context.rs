use crate::nix::get_flake_root;
use miette::{IntoDiagnostic, Result};
use std::fs;
use std::path::PathBuf;

const RIGUP_DIR: &str = ".rigup";
const LAST_RIG_FILE: &str = "last-rig";
const DEFAULT_RIG: &str = "default";

/// Get the path to the .rigup directory in the flake root
fn get_rigup_dir() -> Result<PathBuf> {
    let flake_root = get_flake_root()?;
    Ok(flake_root.join(RIGUP_DIR))
}

/// Get the path to the last-rig file
fn get_last_rig_file() -> Result<PathBuf> {
    Ok(get_rigup_dir()?.join(LAST_RIG_FILE))
}

/// Load the last used rig name, or return "default" if none exists
pub fn get_last_used_rig() -> Result<String> {
    let last_rig_path = get_last_rig_file()?;

    if !last_rig_path.exists() {
        return Ok(DEFAULT_RIG.to_string());
    }

    let contents = fs::read_to_string(&last_rig_path).into_diagnostic()?;
    let rig_name = contents.trim();

    if rig_name.is_empty() {
        Ok(DEFAULT_RIG.to_string())
    } else {
        Ok(rig_name.to_string())
    }
}

/// Save the rig name as the last used rig
pub fn save_last_used_rig(rig_name: &str) -> Result<()> {
    let rigup_dir = get_rigup_dir()?;

    // Create .rigup directory if it doesn't exist
    if !rigup_dir.exists() {
        fs::create_dir_all(&rigup_dir).into_diagnostic()?;
    }

    // Write the rig name to the file
    let last_rig_path = get_last_rig_file()?;
    fs::write(&last_rig_path, rig_name).into_diagnostic()?;

    Ok(())
}
