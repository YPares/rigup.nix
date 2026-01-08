use crate::types::RigletMeta;
use itertools::Itertools;
use miette::{IntoDiagnostic, Result};
use owo_colors::OwoColorize;
use std::fmt::Write as FmtWrite;
use std::io::{self, IsTerminal, Write};
use std::process::{Command, Stdio};
use textwrap::{wrap, Options};

/// Execute a closure that writes to output, piping through less if stdout is a TTY
pub fn with_output<F>(no_pager: bool, write_fn: F) -> Result<()>
where
    F: FnOnce(&mut dyn Write) -> Result<()>,
{
    let stdout = io::stdout();
    if !no_pager && stdout.is_terminal() {
        // Spawn less with flags:
        // -R: preserve ANSI color codes
        // -S: don't wrap lines (scroll horizontally)
        // -F: quit if content fits on one screen
        // -X: don't clear screen on exit
        let mut child = Command::new("less")
            .args(&["-RSFX", "--mouse", "--wheel-lines=3"])
            .stdin(Stdio::piped())
            .spawn()
            .into_diagnostic()?;
        let mut stdin = child
            .stdin
            .take()
            .ok_or_else(|| miette::miette!("Failed to capture stdin pipe from less process"))?;
        write_fn(&mut stdin)?;
        child.wait().into_diagnostic()?;
    } else {
        // Not a TTY or pager disabled, write directly to stdout
        write_fn(&mut stdout.lock())?;
    }
    Ok(())
}

/// Wrap text to terminal width with a given prefix for each line
pub fn wrap_with_prefix(text: &str, prefix: &str, terminal_width: usize) -> String {
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
pub fn display_riglet(
    output: &mut String,
    name: &str,
    meta: &RigletMeta,
    prefix: &str,
    is_last: bool,
    terminal_width: usize,
    detailed: bool,
    no_descriptions: bool,
) -> Result<()> {
    let branch = if is_last { "└─" } else { "├─" };
    let continuation = if is_last { "   " } else { " │ " };

    let entrypoint_flag = if meta.entrypoint.is_some() {
        format!(" {}", "entrypoint".magenta())
    } else {
        String::new()
    };

    writeln!(
        output,
        "{prefix} {branch} {name} ({version}) {intent}{entrypoint}{status}{disclosure}{broken}",
        prefix = prefix,
        branch = branch,
        name = name.cyan().to_string(),
        version = meta.version,
        intent = meta.intent.blue(),
        entrypoint = entrypoint_flag,
        status = match meta.status.as_str() {
            "experimental" => format!(" {}", meta.status.yellow()),
            "deprecated" | "draft" => format!(" {}", meta.status.red()),
            "example" => format!(" {}", meta.status.cyan()),
            _ => String::new(),
        },
        disclosure = match meta.disclosure.as_str() {
            "lazy" => String::new(),
            "none" if meta.intent == "base" => String::new(), // "base" riglets are always undisclosed
            "none" => format!(" {}", " undisclosed".green()),
            _ => format!(" {}", meta.disclosure.green()),
        },
        broken = if meta.broken { " BROKEN" } else { "" }.red().bold()
    )
    .into_diagnostic()?;

    // Add 2 extra spaces for detail indentation
    let item_prefix = format!("{}{}  ", prefix, continuation);

    // Wrap description (unless no_descriptions is set)
    if !no_descriptions {
        writeln!(
            output,
            "{}",
            wrap_with_prefix(
                &meta.description.bold().to_string(),
                &item_prefix,
                terminal_width
            )
        )
        .into_diagnostic()?;
    }

    if !detailed {
        return Ok(());
    }

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
            "Provides: {}",
            meta.command_names
                .iter()
                .map(|c| c.italic().to_string())
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

    if let Some(program) = &meta.entrypoint {
        writeln!(output, "{}Entrypoint: {}", item_prefix, program.italic()).into_diagnostic()?;
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
