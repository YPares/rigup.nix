# Packaging Python Tools with Nix

Quick reference for packaging Python applications and scripts as Nix derivations.

## Basic Application Packaging: buildPythonApplication

For standalone Python applications (not libraries), use `buildPythonApplication`:

```nix
{ lib, python3, fetchPypi }:

python3.pkgs.buildPythonApplication rec {
  pname = "my-tool";
  version = "1.0.0";

  # Modern pyproject.toml-based projects
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-...";
  };

  # Runtime dependencies
  propagatedBuildInputs = with python3.pkgs; [
    requests
    click
  ];

  # Build-time dependencies (for pyproject builds)
  build-system = with python3.pkgs; [
    setuptools
    wheel
  ];

  meta = with lib; {
    description = "My Python tool";
    homepage = "https://example.com";
    license = licenses.mit;
  };
}
```

## Key Points

**Applications vs Libraries**: `buildPythonApplication` is for end-user tools. Use `buildPythonPackage` for libraries that will be dependencies of other Python packages.

**Modern build systems (2025)**: Set `pyproject = true` for projects using `pyproject.toml`. Specify the build backend in `build-system` (commonly `setuptools`, `hatchling`, `poetry-core`, or `flit-core`).

**Legacy projects**: For older `setup.py`-based projects, use `format = "setuptools"` instead of `pyproject = true`.

**Dependencies**:
- `propagatedBuildInputs`: Runtime Python dependencies
- `build-system`: Build tools (setuptools, wheel, etc.)
- `nativeBuildInputs`: Build-time non-Python tools

## Local Scripts

For simple local scripts included in a riglet:

```nix
{ pkgs, python3, ... }:

let
  myScript = python3.pkgs.buildPythonApplication {
    pname = "my-script";
    version = "0.1.0";

    pyproject = true;

    src = ./scripts/my-script;  # Directory with pyproject.toml

    propagatedBuildInputs = with python3.pkgs; [
      requests
    ];

    build-system = with python3.pkgs; [
      setuptools
    ];
  };
in {
  config.riglets.my-riglet = {
    tools = [ myScript ];
  };
}
```

## Helper Tools

**nix-init**: Automatically generate package expressions for Python projects. Prefetches sources, parses dependencies, and fills in most metadata.

## Further Reading

- **Official nixpkgs Python documentation**: https://github.com/NixOS/nixpkgs/blob/master/doc/languages-frameworks/python.section.md
- **NixOS Wiki - Packaging/Python**: https://wiki.nixos.org/wiki/Packaging/Python
- **Python language guide**: https://ryantm.github.io/nixpkgs/languages-frameworks/python/
- **Tutorial - Using and creating Python packages**: https://fridh.github.io/nix-tutorials/tutorials/02-python/01-using-and-creating-python-packages.html
