use crate::nix::{
    build_flake_ref, get_flake_root, get_system, parse_flake_ref, run_command_inherit,
};
use miette::{IntoDiagnostic, Result};
use std::env;
use std::path::PathBuf;

pub fn build_rig(flake_ref: Option<String>, no_stage: bool) -> Result<()> {
    let system = get_system();
    let (flake_path, rig) = parse_flake_ref(flake_ref.as_deref())?;
    let full_ref = build_flake_ref(&flake_path, &rig, &system, "home", no_stage)?;

    let output_dir = if flake_path == "." {
        // Using current repo - output to repo's .rigup
        let flake_root = get_flake_root()?;
        flake_root.join(".rigup")
    } else {
        // Using external flake - output to $HOME/.rigup
        let home = env::var("HOME")
            .into_diagnostic()
            .map_err(|_| miette::miette!("HOME environment variable not set"))?;
        PathBuf::from(home).join(".rigup")
    };

    // Create output directory if it doesn't exist
    if !output_dir.exists() {
        std::fs::create_dir_all(&output_dir).into_diagnostic()?;
    }

    let output_path = output_dir.join(&rig);
    let output_path_str = output_path.to_string_lossy().to_string();

    eprintln!("Building rig '{}' for system '{}'...", rig, system);
    run_command_inherit("nix", vec!["build", &full_ref, "-o", &output_path_str])?;

    eprintln!("Rig built successfully at: {}", output_path.display());
    Ok(())
}
