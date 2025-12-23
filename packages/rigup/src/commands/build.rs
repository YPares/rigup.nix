use crate::nix::{get_system, run_nix_command};
use miette::Result;

pub fn build_rig(rig: &str) -> Result<()> {
    let system = get_system();
    let flake_ref = format!(".#rigs.{}.{}.home", system, rig);
    let output_path = format!(".rigup/{}", rig);

    println!("Building rig '{}' for system '{}'...", rig, system);
    run_nix_command(vec!["build", &flake_ref, "-o", &output_path])?;
    println!("Rig built successfully at: {}", output_path);
    Ok(())
}
