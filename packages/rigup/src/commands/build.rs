use crate::nix::{get_flake_root, get_system, run_nix_command};
use miette::{IntoDiagnostic, Result};
use std::env;

pub fn build_rig(rig: &str) -> Result<()> {
    let flake_root = get_flake_root()?;
    let system = get_system();
    let flake_ref = format!(".#rigs.{}.{}.home", system, rig);
    let output_path = format!(".rigup/{}", rig);

    // Change to flake root directory
    env::set_current_dir(&flake_root).into_diagnostic()?;

    println!("Building rig '{}' for system '{}'...", rig, system);
    run_nix_command(vec!["build", &flake_ref, "-o", &output_path])?;

    let absolute_output = flake_root.join(&output_path);
    println!("Rig built successfully at: {}", absolute_output.display());
    Ok(())
}
