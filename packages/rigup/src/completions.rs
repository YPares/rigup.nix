use clap_complete::ArgValueCompleter;
use std::ffi::OsString;

/// Custom completer for flake references
pub fn flake_ref_completer() -> ArgValueCompleter {
    ArgValueCompleter::new(move |current| {
        let current_str = current.to_string_lossy();
        let mut candidates = Vec::new();

        // If the input starts with `.#`, complete with local rig names
        if current_str.starts_with(".#") {
            let rig_suffix = &current_str[2..]; // Remove `.#` prefix

            // Try to get available rigs from the local flake
            if let Ok(rigs) = get_local_rigs() {
                for rig in rigs {
                    if rig.starts_with(rig_suffix) {
                        candidates.push(OsString::from(format!(".#{}", rig)));
                    }
                }
            }

            // If no specific match yet, suggest `.#default` as a fallback
            if candidates.is_empty() && rig_suffix.is_empty() {
                candidates.push(OsString::from(".#default"));
            }
        } else if current_str.is_empty() || current_str == "." {
            // Suggest starting with `.#` for local flakes
            candidates.push(OsString::from(".#default"));
        }

        candidates
    })
}

/// Get available rigs from the local flake
fn get_local_rigs() -> Result<Vec<String>, Box<dyn std::error::Error>> {
    use std::process::Command;

    // Get the system (e.g., x86_64-linux)
    let system = get_system()?;

    // Query the flake for available rigs
    let output = Command::new("nix")
        .args([
            "eval",
            "--json",
            ".#rigs",
            "--apply",
            &format!("rigs: builtins.attrNames (rigs.{} or {{}})", system),
        ])
        .output()?;

    if !output.status.success() {
        return Ok(Vec::new()); // Return empty list if query fails
    }

    let rigs: Vec<String> = serde_json::from_slice(&output.stdout)?;
    Ok(rigs)
}

/// Get the current system string (e.g., x86_64-linux)
fn get_system() -> Result<String, Box<dyn std::error::Error>> {
    use std::process::Command;

    let output = Command::new("nix")
        .args(["eval", "--raw", "--impure", "--expr", "builtins.currentSystem"])
        .output()?;

    if !output.status.success() {
        return Err("Failed to get current system".into());
    }

    Ok(String::from_utf8(output.stdout)?)
}
