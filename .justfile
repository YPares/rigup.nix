@_help:
    {{ just_executable() }} --list

# Reformat all files
fmt:
    #!/bin/bash
    echo "-- Nix"
    nix fmt
    for f in packages/*/Cargo.toml; do
        echo "-- $f"
        cargo fmt --manifest-path "$f"
    done

# Build all packages (debug mode)
build:
    #!/bin/bash
    for f in packages/*/Cargo.toml; do
        echo "-- $f"
        cargo build --manifest-path "$f"
    done

# Update all lockfiles
update:
    #!/bin/bash
    echo "-- Nix"
    nix flake update --refresh
    for f in packages/*/Cargo.toml; do
        echo "-- $f"
        cargo update --manifest-path "$f"
    done

# Run all checks/tests
check:
    #!/bin/bash
    echo "-- Nix"
    nix flake check --quiet --quiet
    for f in packages/*/Cargo.toml; do
        echo "-- $f"
        cargo test --manifest-path "$f"
    done

# Run rigup CLI (debug mode)
[positional-arguments]
@run *args:
    cargo run --manifest-path packages/rigup/Cargo.toml -- "$@"
