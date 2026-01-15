use crate::nix::{build_flake_ref, get_system, parse_flake_ref, run_command_inherit};
use miette::Result;

pub fn enter_shell(flake_ref: Option<String>, command: Vec<String>, no_stage: bool) -> Result<()> {
    let system = get_system();
    let (flake_path, rig) = parse_flake_ref(flake_ref.as_deref())?;
    let full_ref = build_flake_ref(&flake_path, &rig, &system, Some("shell"), no_stage)?;

    eprintln!("> Opening {}", full_ref);

    let mut args = vec!["develop", &full_ref];

    if !command.is_empty() {
        args.push("--command");
        args.extend(command.iter().map(|s| s.as_str()));
    }

    run_command_inherit("nix", args)?;
    Ok(())
}
