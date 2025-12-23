use crate::error::RigupError;
use crate::nix::{get_flake_root, get_system};
use crate::types::RigletMeta;
use miette::{IntoDiagnostic, Result};
use owo_colors::OwoColorize;
use std::collections::HashMap;
use std::env;
use std::process::Command;
use textwrap::{wrap, Options};

/// Wrap text to terminal width with a given prefix for each line
fn wrap_with_prefix(text: &str, prefix: &str, terminal_width: usize) -> String {
    let available_width = terminal_width.saturating_sub(prefix.len()).max(40);
    let options = Options::new(available_width)
        .initial_indent("")
        .subsequent_indent("");

    wrap(text, options)
        .iter()
        .map(|line| format!("{}{}", prefix, line))
        .collect::<Vec<_>>()
        .join("\n")
}

pub fn list_inputs() -> Result<()> {
    let flake_root = get_flake_root()?;
    let system = get_system();

    // Change to flake root directory
    env::set_current_dir(&flake_root).into_diagnostic()?;

    // Use the helper function from rigup.lib to discover all riglets in a single evaluation
    let eval_expr = format!(
        "let \
           flake = builtins.getFlake (toString ./.); \
           rigup = if flake ? lib && flake.lib ? discoverInputRiglets \
                   then flake \
                   else flake.inputs.rigup; \
         in rigup.lib.discoverInputRiglets {{ \
           inherit flake; \
           system = \"{}\"; \
         }}",
        system
    );

    println!("Discovering riglets from flake inputs...\n");

    let output = Command::new("nix")
        .args(&["eval", "--impure", "--expr", &eval_expr, "--json"])
        .output()
        .into_diagnostic()?;

    if !output.status.success() {
        let code = output.status.code().unwrap_or(1);
        let stderr = String::from_utf8_lossy(&output.stderr).to_string();
        return Err(RigupError::NixCommandFailed { code, stderr }.into());
    }

    // Parse the nested structure: { input-name -> { riglet-name -> metadata } }
    let all_riglets: HashMap<String, HashMap<String, RigletMeta>> =
        serde_json::from_slice(&output.stdout)
            .map_err(|e| RigupError::MetadataParseError { source: e })?;

    if all_riglets.is_empty() {
        println!("No inputs with riglets found");
        return Ok(());
    }

    // Get terminal width, default to 80 if not available
    let terminal_width = terminal_size::terminal_size()
        .map(|(w, _)| w.0 as usize)
        .unwrap_or(80);

    println!("{}\n", "Flake inputs with riglets:".bold());

    for (input_name, riglets) in all_riglets {
        if !riglets.is_empty() {
            println!("📦 {}", input_name.bright_blue().bold());

            let riglets_vec: Vec<_> = riglets.into_iter().collect();
            let riglets_count = riglets_vec.len();

            for (idx, (riglet_name, meta)) in riglets_vec.into_iter().enumerate() {
                let is_last = idx == riglets_count - 1;
                let branch = if is_last { "└─" } else { "├─" };
                let prefix = if is_last { "     " } else { " │   " };

                println!(
                    " {} {} (v{}){}",
                    branch,
                    if meta.broken {
                        format!("{}", riglet_name.red().bold())
                    } else {
                        riglet_name.green().bold().to_string()
                    },
                    meta.version,
                    (if meta.broken { " BROKEN" } else { "" }).red().bold()
                );

                // Color-code status
                let status_str = match meta.status.as_str() {
                    "stable" => meta.status.green().to_string(),
                    "experimental" => meta.status.yellow().to_string(),
                    "deprecated" | "draft" => meta.status.red().to_string(),
                    "example" => meta.status.blue().to_string(),
                    _ => meta.status,
                };

                println!(
                    "{}Intent: {} {} Status: {}",
                    prefix,
                    meta.intent.cyan().bold(),
                    "|".bright_black(),
                    status_str
                );

                // Wrap description
                println!(
                    "{}",
                    wrap_with_prefix(&meta.description, prefix, terminal_width)
                );

                if !meta.keywords.is_empty() {
                    let wrapped =
                        wrap_with_prefix(&meta.keywords.join(", "), prefix, terminal_width);
                    for line in wrapped.lines() {
                        if let Some(text) = line.strip_prefix(prefix) {
                            println!("{}{}", prefix, text.bright_black().italic());
                        } else {
                            println!("{}", line);
                        }
                    }
                }

                if !meta.when_to_use.is_empty() {
                    println!("{}When to use:", prefix);
                    for use_case in &meta.when_to_use {
                        let bullet_prefix = format!("{}   ", prefix);
                        let wrapped = wrap_with_prefix(use_case, &bullet_prefix, terminal_width);
                        // Add cyan bullet to first line only
                        let lines: Vec<&str> = wrapped.lines().collect();
                        if let Some((first, rest)) = lines.split_first() {
                            // Extract the actual text after the prefix
                            let text = first.strip_prefix(&bullet_prefix).unwrap_or(first);
                            println!("{} {} {}", prefix, "•".magenta(), text);
                            for line in rest {
                                println!("{}", line);
                            }
                        }
                    }
                }
            }
            println!();
        }
    }

    Ok(())
}
