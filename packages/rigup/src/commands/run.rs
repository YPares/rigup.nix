use crate::nix::{build_flake_ref, get_system, parse_flake_ref, prepare_local_overrides};
use miette::{IntoDiagnostic, Result};
use std::process::Command;

pub fn run_entrypoint(flake_ref: Option<String>, extra_args: &[String]) -> Result<()> {
    let system = get_system();
    let (flake_path, rig) = parse_flake_ref(flake_ref.as_deref())?;
    let entrypoint_ref = build_flake_ref(&flake_path, &rig, &system, "entrypoint")?;

    eprintln!("Running entrypoint for rig '{}'...", rig);

    // Prepare local configuration overrides
    let local_overrides = prepare_local_overrides()?;

    // Use nix run directly on the entrypoint derivation
    let mut cmd = Command::new("nix");
    cmd.arg("run");

    local_overrides.apply_to_command(&mut cmd);

    cmd.arg(&entrypoint_ref);

    // Forward extra arguments to the entrypoint after --
    if !extra_args.is_empty() {
        cmd.arg("--");
        cmd.args(extra_args);
    }

    let status = cmd.status().into_diagnostic()?;

    if !status.success() {
        let code = status.code().unwrap_or(1);
        return Err(miette::miette!("Entrypoint exited with status: {}", code));
    }

    Ok(())
}
