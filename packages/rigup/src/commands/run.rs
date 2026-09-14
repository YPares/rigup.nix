use crate::nix::{build_flake_ref, get_system, nix_build_print_out_path, parse_flake_ref};
use miette::{diagnostic, IntoDiagnostic, Report, Result};
use std::path::{Path, PathBuf};
use std::process::Command;

/// Locate the entrypoint's executable inside its output folder.
///
/// The riglet schema guarantees the entrypoint is a folder derivation with a
/// SINGLE `bin/<exe>` (see `lib/rigletSchema.nix`).
fn entrypoint_executable(entrypoint_path: &str) -> Result<PathBuf> {
    let bin_dir = Path::new(entrypoint_path).join("bin");
    let mut executables = std::fs::read_dir(&bin_dir)
        .into_diagnostic()?
        .filter_map(|entry| entry.ok())
        .map(|entry| entry.path())
        .collect::<Vec<_>>();
    executables.sort();

    match executables.as_slice() {
        [executable] => Ok(executable.clone()),
        _ => Err(miette::miette!(
            "Expected exactly one executable in {}, found {}",
            bin_dir.display(),
            executables.len()
        )),
    }
}

pub fn run_entrypoint(
    flake_ref: Option<String>,
    extra_args: &[String],
    no_stage: bool,
) -> Result<()> {
    let system = get_system();
    let (flake_path, rig) = parse_flake_ref(flake_ref.as_deref())?;
    let entrypoint_ref = build_flake_ref(&flake_path, &rig, &system, Some("entrypoint"), no_stage)?;

    // We deliberately do NOT use `nix run` here: on a flake reference it bypasses
    // Nix's evaluation cache and re-evaluates the whole flake (nixpkgs included)
    // on every invocation, which costs several seconds even when the entrypoint
    // is already built. `nix build` uses that cache, so it only re-evaluates when
    // the flake's fingerprint actually changes.
    eprintln!("> Building {}", entrypoint_ref);
    let entrypoint_path = nix_build_print_out_path(&entrypoint_ref)?;
    let executable = entrypoint_executable(&entrypoint_path)?;

    eprintln!("> Running {:?}", executable);
    let status = Command::new(&executable)
        .args(extra_args)
        .status()
        .into_diagnostic()?;

    if status.success() {
        Ok(())
    } else {
        Err(Report::from(
            diagnostic!("entrypoint exited with code {}", status.code().unwrap_or(1)).with_help(
                format!(
                    "Check that rig '{}' exists and does provide an entrypoint",
                    rig
                ),
            ),
        ))
    }
}
