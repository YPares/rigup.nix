use crate::nix::{get_system, run_nix_command};
use miette::Result;

pub fn enter_shell(rig: &str, command: Vec<String>) -> Result<()> {
    let system = get_system();
    let flake_ref = format!(".#rigs.{}.{}.shell", system, rig);

    let mut args = vec!["develop", &flake_ref];

    if command.len() != 0 {
        args.push("--command");
        args.extend(command.iter().map(|s| s.as_str()));
    }

    run_nix_command(args)?;
    Ok(())
}
