use crate::error::RigupError;
use crate::nix::{get_flake_root, get_system, prepare_local_overrides, run_nix_eval_json};
use crate::types::{InputData, RigletMeta};
use itertools::Itertools;
use miette::Result;
use owo_colors::OwoColorize;
use std::collections::HashMap;
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
        .join("\n")
}

/// Display a riglet's metadata with tree formatting
fn display_riglet(
    name: &str,
    meta: &RigletMeta,
    prefix: &str,
    is_last: bool,
    terminal_width: usize,
) {
    let branch = if is_last { "└─" } else { "├─" };
    let continuation = if is_last { "   " } else { " │ " };

    println!(
        "{} {} {} (v{}){}",
        prefix,
        branch,
        if meta.broken {
            name.red().to_string()
        } else {
            name.green().to_string()
        },
        meta.version,
        (if meta.broken { " BROKEN" } else { "" }).red().bold()
    );

    // Add 2 extra spaces for detail indentation
    let item_prefix = format!("{}{}  ", prefix, continuation);

    // Color-code status
    let status_str = match meta.status.as_str() {
        "stable" => meta.status.green().to_string(),
        "experimental" => meta.status.yellow().to_string(),
        "deprecated" | "draft" => meta.status.red().to_string(),
        "example" => meta.status.blue().to_string(),
        _ => meta.status.clone(),
    };

    println!(
        "{}Intent: {} {} Status: {}",
        item_prefix,
        meta.intent.cyan().bold(),
        "|".bright_black(),
        status_str.bold()
    );

    // Wrap description
    println!(
        "{}",
        wrap_with_prefix(&meta.description, &item_prefix, terminal_width)
    );

    if !meta.keywords.is_empty() {
        let wrapped = wrap_with_prefix(&meta.keywords.join(", "), &item_prefix, terminal_width);
        for line in wrapped.lines() {
            if let Some(text) = line.strip_prefix(&item_prefix) {
                println!("{}{}", item_prefix, text.bright_black().italic());
            } else {
                println!("{}", line);
            }
        }
    }

    if !meta.command_names.is_empty() {
        let commands_text = format!(
            "Tools: {}",
            meta.command_names
                .iter()
                .map(|c| c.cyan().to_string())
                .join(", ")
        );
        let wrapped = wrap_with_prefix(&commands_text, &item_prefix, terminal_width);
        for line in wrapped.lines() {
            if let Some(text) = line.strip_prefix(&item_prefix) {
                println!("{}{}", item_prefix, text);
            } else {
                println!("{}", line);
            }
        }
    }

    if !meta.when_to_use.is_empty() {
        println!("{}When to use:", item_prefix);
        for use_case in &meta.when_to_use {
            let bullet_prefix = format!("{}   ", item_prefix);
            let wrapped = wrap_with_prefix(use_case, &bullet_prefix, terminal_width);
            let lines: Vec<&str> = wrapped.lines().collect();
            if let Some((first, rest)) = lines.split_first() {
                let text = first.strip_prefix(&bullet_prefix).unwrap_or(first);
                println!("{} {} {}", item_prefix, "•".magenta(), text);
                for line in rest {
                    println!("{}", line);
                }
            }
        }
    }
}

pub fn list_inputs(flake: Option<String>, include_inputs: bool) -> Result<()> {
    let system = get_system();
    let flake_path = flake.unwrap_or_else(|| ".".to_string());

    // Prepare local configuration overrides
    let local_overrides = prepare_local_overrides()?;

    // Build the flake expression
    let flake_expr = if flake_path == "." {
        let flake_root = get_flake_root()?;
        format!("builtins.getFlake \"{}\"", flake_root.display())
    } else {
        format!("builtins.getFlake \"{}\"", flake_path)
    };

    // Use the helper function from rigup.lib to discover all riglets and rigs
    let eval_expr = format!(
        "let \
           flake = {}; \
           rigup = if flake ? lib && flake.lib ? listFlake \
                   then flake \
                   else flake.inputs.rigup; \
         in rigup.lib.listFlake {{ \
           inherit flake; \
           system = \"{}\"; \
           includeInputs = {}; \
         }}",
        flake_expr, system, include_inputs
    );

    eprintln!("Discovering riglets and rigs...");

    // Run nix eval and parse the result
    // Always use impure mode since the eval expression uses builtins.getFlake
    let result = run_nix_eval_json(&eval_expr, &local_overrides, true)?;

    // Parse the nested structure: { input-name -> { riglets = {...}, rigs = {...} } }
    let all_data: HashMap<String, InputData> =
        serde_json::from_value(result).map_err(|e| RigupError::MetadataParseError { source: e })?;

    if all_data.is_empty() {
        eprintln!("No inputs with riglets or rigs found");
        return Ok(());
    }

    eprintln!("");

    // Get terminal width, default to 80 if not available
    let terminal_width = terminal_size::terminal_size()
        .map(|(w, _)| w.0 as usize)
        .unwrap_or(80);

    // Sort inputs alphabetically for stable output
    let mut sorted_inputs: Vec<_> = all_data.into_iter().collect();
    sorted_inputs.sort_by(|a, b| a.0.cmp(&b.0));

    for (input_name, data) in sorted_inputs {
        let has_riglets = !data.riglets.is_empty();
        let has_rigs = !data.rigs.is_empty();

        if !has_riglets && !has_rigs {
            continue;
        }

        println!("📦 {}", input_name.bright_blue().bold());

        // Count total sections (riglets and rigs)
        let section_count = (if has_riglets { 1 } else { 0 }) + (if has_rigs { 1 } else { 0 });
        let mut section_idx = 0;

        // Display riglets section
        if has_riglets {
            section_idx += 1;
            let is_last_section = section_idx == section_count;
            let section_branch = if is_last_section { "└─" } else { "├─" };
            // Emoji takes 2 chars, so we need extra space for alignment
            let section_prefix = if is_last_section { "   " } else { " │ " };

            println!(" {}🧩 {}", section_branch, "Riglets".bold());

            let mut riglets_vec: Vec<_> = data.riglets.into_iter().collect();
            riglets_vec.sort_by(|a, b| a.0.cmp(&b.0));
            let riglets_count = riglets_vec.len();

            for (idx, (riglet_name, meta)) in riglets_vec.into_iter().enumerate() {
                let is_last = idx == riglets_count - 1;
                display_riglet(&riglet_name, &meta, section_prefix, is_last, terminal_width);
            }
        }

        // Display rigs section
        if has_rigs {
            section_idx += 1;
            let is_last_section = section_idx == section_count;
            let section_branch = if is_last_section { "└─" } else { "├─" };
            // Emoji takes 2 chars, so we need extra space for alignment
            let section_prefix = if is_last_section { "   " } else { " │ " };

            println!(" {}📟 {}", section_branch, "Rigs".bold());

            let mut rigs_vec: Vec<_> = data.rigs.into_iter().collect();
            rigs_vec.sort_by(|a, b| a.0.cmp(&b.0));
            let rigs_count = rigs_vec.len();

            for (idx, (rig_name, rig_meta)) in rigs_vec.into_iter().enumerate() {
                let is_last_rig = idx == rigs_count - 1;
                let rig_branch = if is_last_rig { "└─" } else { "├─" };
                let rig_continuation = if is_last_rig { "   " } else { " │ " };

                println!("{} {} {}", section_prefix, rig_branch, rig_name.cyan());

                // Display riglets in this rig as comma-separated list (like keywords)
                if !rig_meta.riglets.is_empty() {
                    let mut riglet_list: Vec<String> = rig_meta
                        .riglets
                        .iter()
                        .map(|(name, _)| name.clone())
                        .collect();
                    riglet_list.sort();

                    // Add 2 extra spaces for detail indentation
                    let item_prefix = format!("{}{}  ", section_prefix, rig_continuation);
                    let wrapped =
                        wrap_with_prefix(&riglet_list.join(", "), &item_prefix, terminal_width);

                    for line in wrapped.lines() {
                        if let Some(text) = line.strip_prefix(&item_prefix) {
                            println!("{}{}", item_prefix, text.bright_black().italic());
                        } else {
                            println!("{}", line);
                        }
                    }
                }

                // Display entrypoint if defined
                if let Some(program) = &rig_meta.entrypoint {
                    let item_prefix = format!("{}{}  ", section_prefix, rig_continuation);
                    println!("{}Entrypoint: {}", item_prefix, program.magenta());
                }
            }
        }

        println!();
    }

    Ok(())
}
