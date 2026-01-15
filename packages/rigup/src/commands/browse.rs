use crate::nix::{build_flake_ref, get_system, parse_flake_ref, run_command_inherit};
use miette::Result;
use std::env;
use std::path::PathBuf;
use std::process::{Command, Stdio};

pub fn browse_rig_docs(
    browser: Option<String>,
    flake_ref: Option<String>,
    no_stage: bool,
) -> Result<()> {
    let system = get_system();
    let (flake_path, rig) = parse_flake_ref(flake_ref.as_deref())?;
    let full_ref = build_flake_ref(&flake_path, &rig, &system, Some("docRoot"), no_stage)?;

    eprintln!("> Building {}", full_ref);

    let output = Command::new("nix")
        .args(&["build", &full_ref, "--no-link", "--print-out-paths"])
        .stderr(Stdio::inherit())
        .output()
        .map_err(|e| miette::miette!("Failed to evaluate docRoot: {}", e))?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(miette::miette!("Failed to get docRoot: {}", stderr));
    }

    let doc_path_str = String::from_utf8(output.stdout)
        .map_err(|e| miette::miette!("Invalid UTF-8 in path: {}", e))?;

    let doc_path = PathBuf::from(doc_path_str.trim_end());

    if !doc_path.exists() {
        return Err(miette::miette!(
            "Documentation path does not exist: {}",
            doc_path.display()
        ));
    }

    // Default to $EDITOR if no browser specified
    let program =
        browser.unwrap_or_else(|| env::var("EDITOR").unwrap_or_else(|_| "less".to_string()));

    eprintln!("> Opening {}", doc_path.display());

    run_command_inherit(&program, vec![doc_path.to_str().unwrap()])?;

    Ok(())
}
