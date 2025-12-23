use crate::nix::{get_flake_root, get_system, run_nix_command};
use miette::Result;

pub fn enter_shell(rig: &str, command: Vec<String>) -> Result<()> {
    let flake_root = get_flake_root()?;
    let system = get_system();

    // Use absolute path to flake so we can stay in current directory
    let flake_ref = format!("{}#rigs.{}.{}.shell", flake_root.display(), system, rig);

    let mut args = vec!["develop", &flake_ref];

    if !command.is_empty() {
        args.push("--command");
        args.extend(command.iter().map(|s| s.as_str()));
    }

    run_nix_command(args)?;
    Ok(())
}
