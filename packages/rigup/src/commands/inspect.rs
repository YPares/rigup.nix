use crate::display::{display_riglet, with_output, wrap_with_prefix};
use crate::error::RigupError;
use crate::nix::{
    build_flake_ref, get_system, parse_flake_ref, resolve_flake_path, run_nix_eval_json,
};
use crate::types::{ConfigOption, ConfigValue, RigInspection};
use itertools::Itertools;
use miette::{IntoDiagnostic, Result};
use owo_colors::OwoColorize;
use serde_json::Value;
use std::collections::HashMap;
use std::io::Write;

/// Format a JSON value for display
fn format_value(value: &Value) -> String {
    match value {
        Value::String(s) => format!("\"{}\"", s),
        Value::Number(n) => n.to_string(),
        Value::Bool(b) => b.to_string(),
        Value::Null => "null".to_string(),
        Value::Array(arr) => {
            if arr.len() <= 3 {
                format!("[{}]", arr.iter().map(format_value).join(" "))
            } else {
                format!("[...{} items...]", arr.len())
            }
        }
        Value::Object(obj) => {
            if obj.len() <= 3 {
                format!(
                    "{{ {}}}",
                    obj.iter()
                        .map(|(k, v)| format!("{} = {}; ", k, format_value(v)))
                        .join("")
                )
            } else {
                format!("{{...{} items...}}", obj.len())
            }
        }
    }
}

/// Display a config option with tree formatting
fn display_config_option(
    output: &mut dyn Write,
    name: &str,
    option: &ConfigOption,
    prefix: &str,
    is_last: bool,
    terminal_width: usize,
    detailed: bool,
    no_descriptions: bool,
) -> Result<()> {
    let branch = if is_last { "└─" } else { "├─" };
    let continuation = if is_last { "   " } else { " │ " };

    // Option name, type, and value on one line
    let value_display = match (&option.value, &option.default) {
        (Some(value), Some(default)) if value == default => format!(
            "{} {}",
            format_value(value).blue(),
            format!(": {}", option.option_type).bright_black()
        ),
        (Some(value), Some(default)) => format!(
            "{} {}",
            format_value(value).yellow(),
            format!(": {}, def. {}", option.option_type, default).bright_black()
        ),
        (Some(value), None) => format!(
            "{} {}",
            format_value(value).yellow(),
            format!(": {}", option.option_type).bright_black()
        ),
        (None, None) => format!(
            "{} {}",
            "null".blue().italic(),
            format!(": {}", option.option_type).bright_black()
        ),
        _ => format!(
            "{} {}",
            "null".yellow().italic(),
            format!(": {}", option.option_type).bright_black()
        ),
    };

    writeln!(
        output,
        "{} {} {} = {}",
        prefix,
        branch,
        name.cyan(),
        value_display
    )
    .into_diagnostic()?;

    let item_prefix = format!("{}{}  ", prefix, continuation);

    // Description (unless no_descriptions is set)
    if !no_descriptions {
        if let Some(desc) = &option.description {
            writeln!(
                output,
                "{}",
                wrap_with_prefix(&desc.to_string(), &item_prefix, terminal_width)
            )
            .into_diagnostic()?;
        }
    }

    // Show detailed info only if detailed flag is set
    if detailed {
        // Enum values (if applicable)
        if let Some(enum_vals) = &option.enum_values {
            if !enum_vals.is_empty() {
                let values_str = enum_vals.iter().map(format_value).join(", ");
                let wrapped = wrap_with_prefix(&values_str, &item_prefix, terminal_width);
                for line in wrapped.lines() {
                    match line.strip_prefix(&item_prefix) {
                        Some(text) => {
                            writeln!(output, "{}{}", item_prefix, text).into_diagnostic()?;
                        }
                        None => {
                            writeln!(output, "{}", line).into_diagnostic()?;
                        }
                    }
                }
            }
        }
    }

    Ok(())
}

/// Display config values recursively
fn display_config_values(
    output: &mut dyn Write,
    values: &HashMap<String, ConfigValue>,
    prefix: &str,
    terminal_width: usize,
    detailed: bool,
    no_descriptions: bool,
) -> Result<()> {
    let mut sorted_keys: Vec<_> = values.keys().collect();
    sorted_keys.sort();
    let count = sorted_keys.len();

    for (idx, key) in sorted_keys.into_iter().enumerate() {
        let is_last = idx == count - 1;
        let value = &values[key];

        match value {
            ConfigValue::Option(opt) => {
                display_config_option(
                    output,
                    key,
                    opt,
                    prefix,
                    is_last,
                    terminal_width,
                    detailed,
                    no_descriptions,
                )?;
            }
            ConfigValue::Nested(nested) => {
                let branch = if is_last { "└─" } else { "├─" };

                writeln!(output, "{} {}┓ {}", prefix, branch, key.italic()).into_diagnostic()?;

                let continuation = if is_last { "  " } else { " │" };
                let nested_prefix = format!("{}{}", prefix, continuation);
                display_config_values(
                    output,
                    nested,
                    &nested_prefix,
                    terminal_width,
                    detailed,
                    no_descriptions,
                )?;
            }
        }
    }

    Ok(())
}

pub fn inspect_rig(
    flake_ref: Option<String>,
    no_pager: bool,
    detailed: bool,
    no_descriptions: bool,
    no_stage: bool,
) -> Result<()> {
    let system = get_system();

    // Parse flake reference
    let (flake_path, rig_attrpath) = parse_flake_ref(flake_ref.as_deref())?;

    // Resolve flake path and ensure rigup.local.toml is staged if needed
    let flake_expr = resolve_flake_path(&flake_path, no_stage)?;

    // Use inspectRig to get detailed rig information
    let eval_expr = format!(
        r###"
            let
                flake = builtins.getFlake "{flake}";
                rig = flake.rigs.{system}.{rig} or (throw ''
                    Flake '{flake}' does not output {rig}
                '');
            in {{
                name = "{rig}";
                riglets = rig.meta or {{ }};
                entrypoint = rig.entrypoint.name or null;
                options = rig.configOptions or {{ }};
            }}
        "###,
        flake = flake_expr,
        system = system,
        rig = rig_attrpath
    );

    let flake_ref = build_flake_ref(&flake_path, &rig_attrpath, &system, None, no_stage)?;
    eprintln!("> Inspecting {}", &flake_ref);

    // Run nix eval and parse the result
    let result = run_nix_eval_json(&eval_expr)?;

    // Parse the rig inspection data
    let inspection: RigInspection =
        serde_json::from_value(result).map_err(|e| RigupError::MetadataParseError { source: e })?;

    eprintln!("");

    // Get terminal width, default to 80 if not available
    let terminal_width = terminal_size::terminal_size()
        .map(|(w, _)| w.0 as usize)
        .unwrap_or(80);

    // Stream output directly through less or stdout
    with_output(no_pager, |output| {
        // Display rig header
        writeln!(
            output,
            "📟 {} {}",
            inspection.name.bright_blue().bold(),
            if let Some(ref prog) = inspection.entrypoint {
                format!("(entrypoint: {})", prog.magenta())
            } else {
                String::new()
            }
        )
        .into_diagnostic()?;

        // Display riglets section
        if !inspection.riglets.is_empty() {
            writeln!(output, " ├─🧩 {}", "Riglets".bold()).into_diagnostic()?;

            let mut riglets_vec: Vec<_> = inspection.riglets.iter().collect();
            riglets_vec.sort_by(|a, b| a.0.cmp(b.0));
            let riglets_count = riglets_vec.len();

            for (idx, (riglet_name, meta)) in riglets_vec.into_iter().enumerate() {
                let is_last = idx == riglets_count - 1;
                // display_riglet still uses String internally for wrapping,
                // but we write it out immediately
                display_riglet(
                    output,
                    riglet_name,
                    meta,
                    " │ ",
                    is_last,
                    terminal_width,
                    detailed,
                    no_descriptions,
                )?;
            }
        }

        // Display config options section
        if !inspection.options.is_empty() {
            let section_branch = if inspection.riglets.is_empty() {
                "└─"
            } else {
                "└─"
            };
            let section_prefix = "   ";

            writeln!(output, " {}⚙️  {}", section_branch, "Configuration".bold())
                .into_diagnostic()?;

            display_config_values(
                output,
                &inspection.options,
                section_prefix,
                terminal_width,
                detailed,
                no_descriptions,
            )?;
        }

        Ok(())
    })?;

    Ok(())
}
