use crate::error::RigupError;
use crate::nix::{get_system, resolve_flake_path, run_nix_eval_json};
use crate::types::{InputData, RigletMeta};
use itertools::Itertools;
use miette::{IntoDiagnostic, Result};
use owo_colors::OwoColorize;
use std::collections::HashMap;
use std::fmt::Write as FmtWrite;
use std::io::{self, IsTerminal, Write};
use std::process::{Command, Stdio};
use textwrap::{wrap, Options};

/// Pipe output through less if stdout is a TTY, otherwise print directly
fn pipe_through_less(content: &str, no_pager: bool) -> Result<()> {
    let stdout = io::stdout();

    // Check if stdout is a TTY and pager is not disabled
    if stdout.is_terminal() && !no_pager {
        // Spawn less with flags:
        // -R: preserve ANSI color codes
        // -F: quit if content fits on one screen
        // -X: don't clear screen on exit
        let mut child = Command::new("less")
            .args(&["-RFX", "--mouse", "--wheel-lines=3"])
            .stdin(Stdio::piped())
            .spawn()
            .into_diagnostic()?;

        if let Some(mut stdin) = child.stdin.take() {
            stdin.write_all(content.as_bytes()).into_diagnostic()?;
        }

        child.wait().into_diagnostic()?;
    } else {
        // Not a TTY or pager disabled, just print directly
        print!("{}", content);
    }

    Ok(())
}

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
    output: &mut String,
    name: &str,
    meta: &RigletMeta,
    prefix: &str,
    is_last: bool,
    terminal_width: usize,
) -> Result<()> {
    let branch = if is_last { "└─" } else { "├─" };
    let continuation = if is_last { "   " } else { " │ " };

    writeln!(
        output,
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
    )
    .into_diagnostic()?;

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

    writeln!(
        output,
        "{}Intent: {} {} Status: {}",
        item_prefix,
        meta.intent.cyan().bold(),
        "|".bright_black(),
        status_str.bold()
    )
    .into_diagnostic()?;

    // Wrap description
    writeln!(
        output,
        "{}",
        wrap_with_prefix(&meta.description, &item_prefix, terminal_width)
    )
    .into_diagnostic()?;

    if !meta.keywords.is_empty() {
        let wrapped = wrap_with_prefix(&meta.keywords.join(", "), &item_prefix, terminal_width);
        for line in wrapped.lines() {
            if let Some(text) = line.strip_prefix(&item_prefix) {
                writeln!(output, "{}{}", item_prefix, text.bright_black().italic())
                    .into_diagnostic()?;
            } else {
                writeln!(output, "{}", line).into_diagnostic()?;
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
                writeln!(output, "{}{}", item_prefix, text).into_diagnostic()?;
            } else {
                writeln!(output, "{}", line).into_diagnostic()?;
            }
        }
    }

    if !meta.when_to_use.is_empty() {
        writeln!(output, "{}When to use:", item_prefix).into_diagnostic()?;
        for use_case in &meta.when_to_use {
            let bullet_prefix = format!("{}   ", item_prefix);
            let wrapped = wrap_with_prefix(use_case, &bullet_prefix, terminal_width);
            let lines: Vec<&str> = wrapped.lines().collect();
            if let Some((first, rest)) = lines.split_first() {
                let text = first.strip_prefix(&bullet_prefix).unwrap_or(first);
                writeln!(output, "{} {} {}", item_prefix, "•".magenta(), text).into_diagnostic()?;
                for line in rest {
                    writeln!(output, "{}", line).into_diagnostic()?;
                }
            }
        }
    }

    Ok(())
}

pub fn list_inputs(flake: Option<String>, include_inputs: bool, no_pager: bool) -> Result<()> {
    let system = get_system();
    let flake_path = flake.unwrap_or_else(|| ".".to_string());

    // Resolve flake path and ensure rigup.local.toml is staged if needed
    let flake_expr = resolve_flake_path(&flake_path)?;

    // Use the helper function from rigup.lib to discover all riglets and rigs
    let eval_expr = format!(
        "let \
           flake = builtins.getFlake \"{}\"; \
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
    let result = run_nix_eval_json(&eval_expr)?;

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

    // Collect output into a buffer
    let mut output = String::new();

    for (input_name, data) in sorted_inputs {
        let has_riglets = !data.riglets.is_empty();
        let has_rigs = !data.rigs.is_empty();

        if !has_riglets && !has_rigs {
            continue;
        }

        writeln!(output, "📦 {}", input_name.bright_blue().bold()).into_diagnostic()?;

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

            writeln!(output, " {}🧩 {}", section_branch, "Riglets".bold()).into_diagnostic()?;

            let mut riglets_vec: Vec<_> = data.riglets.into_iter().collect();
            riglets_vec.sort_by(|a, b| a.0.cmp(&b.0));
            let riglets_count = riglets_vec.len();

            for (idx, (riglet_name, meta)) in riglets_vec.into_iter().enumerate() {
                let is_last = idx == riglets_count - 1;
                display_riglet(
                    &mut output,
                    &riglet_name,
                    &meta,
                    section_prefix,
                    is_last,
                    terminal_width,
                )?;
            }
        }

        // Display rigs section
        if has_rigs {
            section_idx += 1;
            let is_last_section = section_idx == section_count;
            let section_branch = if is_last_section { "└─" } else { "├─" };
            // Emoji takes 2 chars, so we need extra space for alignment
            let section_prefix = if is_last_section { "   " } else { " │ " };

            writeln!(output, " {}📟 {}", section_branch, "Rigs".bold()).into_diagnostic()?;

            let mut rigs_vec: Vec<_> = data.rigs.into_iter().collect();
            rigs_vec.sort_by(|a, b| a.0.cmp(&b.0));
            let rigs_count = rigs_vec.len();

            for (idx, (rig_name, rig_meta)) in rigs_vec.into_iter().enumerate() {
                let is_last_rig = idx == rigs_count - 1;
                let rig_branch = if is_last_rig { "└─" } else { "├─" };
                let rig_continuation = if is_last_rig { "   " } else { " │ " };

                writeln!(
                    output,
                    "{} {} {}",
                    section_prefix,
                    rig_branch,
                    rig_name.cyan()
                )
                .into_diagnostic()?;

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
                            writeln!(output, "{}{}", item_prefix, text.bright_black().italic())
                                .into_diagnostic()?;
                        } else {
                            writeln!(output, "{}", line).into_diagnostic()?;
                        }
                    }
                }

                // Display entrypoint if defined
                if let Some(program) = &rig_meta.entrypoint {
                    let item_prefix = format!("{}{}  ", section_prefix, rig_continuation);
                    writeln!(output, "{}Entrypoint: {}", item_prefix, program.magenta())
                        .into_diagnostic()?;
                }
            }
        }

        writeln!(output).into_diagnostic()?;
    }

    // Pipe output through less if stdout is a TTY and pager is not disabled
    pipe_through_less(&output, no_pager)?;

    Ok(())
}
