use miette::Diagnostic;
use std::fmt;

#[derive(Debug, Diagnostic)]
pub enum RigupError {
    #[diagnostic(help("Check that nix is installed and the flake is valid"))]
    NixCommandFailed {
        code: i32,
        #[source_code]
        stderr: String,
    },

    #[diagnostic(help("The JSON output from nix eval may be malformed"))]
    MetadataParseError { source: serde_json::Error },
}

impl fmt::Display for RigupError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            RigupError::NixCommandFailed { code, stderr } => {
                write!(f, "Nix command failed with exit code {}:\n{}", code, stderr)
            }
            RigupError::MetadataParseError { .. } => {
                write!(f, "Failed to parse riglet metadata")
            }
        }
    }
}

impl std::error::Error for RigupError {
    fn source(&self) -> Option<&(dyn std::error::Error + 'static)> {
        match self {
            RigupError::NixCommandFailed { .. } => None,
            RigupError::MetadataParseError { source } => Some(source),
        }
    }
}
