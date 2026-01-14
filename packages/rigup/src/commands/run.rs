use crate::nix::{build_flake_ref, get_system, parse_flake_ref};
use miette::{diagnostic, IntoDiagnostic, Report, Result};
use std::process::Command;

pub fn run_entrypoint(
    flake_ref: Option<String>,
    extra_args: &[String],
    no_stage: bool,
) -> Result<()> {
    let system = get_system();
    let (flake_path, rig) = parse_flake_ref(flake_ref.as_deref())?;
    let entrypoint_ref = build_flake_ref(&flake_path, &rig, &system, "entrypoint", no_stage)?;

    eprintln!("Running entrypoint for rig '{}'...", rig);

    // Use nix run directly on the entrypoint derivation
    let mut cmd = Command::new("nix");
    cmd.args(&["run", &entrypoint_ref]);

    // Forward extra arguments to the entrypoint after --
    if !extra_args.is_empty() {
        cmd.arg("--");
        cmd.args(extra_args);
    }

    let status = cmd.status().into_diagnostic()?;

    if status.success() {
        Ok(())
    } else {
        Err(Report::from(
            diagnostic!("'nix run' exited with code {}", status.code().unwrap_or(1)).with_help(
                format!(
                    "Check that rig '{}' exists and does provide an entrypoint",
                    rig
                ),
            ),
        ))
    }
}
