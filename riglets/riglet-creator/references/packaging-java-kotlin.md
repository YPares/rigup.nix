# Packaging Java/Kotlin Tools with Nix

Quick reference for packaging Java and Kotlin applications as Nix derivations.

## Maven Projects: buildMavenPackage

For Maven-based projects (works for Java, Kotlin, Scala, and other JVM languages):

```nix
{ lib, maven, fetchFromGitHub }:

maven.buildMavenPackage rec {
  pname = "my-java-tool";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "example";
    repo = "my-tool";
    rev = "v${version}";
    hash = "sha256-...";
  };

  # Hash of Maven dependencies
  mvnHash = "sha256-...";

  # Optional: specify which artifact to install
  installPhase = ''
    runHook preInstall
    install -Dm644 target/my-tool-${version}.jar $out/share/java/my-tool.jar
    runHook postInstall
  '';

  meta = with lib; {
    description = "My Java/Kotlin tool";
    homepage = "https://example.com";
    license = licenses.asl20;
  };
}
```

## Getting the mvnHash

Use a fake hash initially:

```nix
mvnHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
```

Build and Nix will provide the correct hash.

## Standard Installation

After building, `buildMavenPackage` automatically:
- Saves `.jar` to `$out/share/java`
- Creates a wrapper script for execution (if there's a main class)

## Gradle Projects

**Status (2025)**: Gradle support is improving but remains challenging compared to Maven.

For Gradle projects, consider these approaches:

### 1. Pre-built Binary Wrapping

Package the pre-built JAR/binary with proper Java runtime:

```nix
{ lib, stdenv, makeWrapper, jre, fetchurl }:

stdenv.mkDerivation rec {
  pname = "my-kotlin-tool";
  version = "1.0.0";

  src = fetchurl {
    url = "https://example.com/releases/my-tool-${version}.jar";
    hash = "sha256-...";
  };

  nativeBuildInputs = [ makeWrapper ];

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/java
    cp $src $out/share/java/my-tool.jar

    mkdir -p $out/bin
    makeWrapper ${jre}/bin/java $out/bin/my-tool \
      --add-flags "-jar $out/share/java/my-tool.jar"

    runHook postInstall
  '';

  meta = with lib; {
    description = "My Kotlin tool";
    license = licenses.mit;
    mainProgram = "my-tool";
  };
}
```

### 2. Manual Gradle Build

For simpler Gradle projects, build manually:

```nix
{ lib, stdenv, gradle, jdk, makeWrapper }:

stdenv.mkDerivation {
  pname = "my-gradle-app";
  version = "1.0.0";
  src = ./.;

  nativeBuildInputs = [ gradle jdk makeWrapper ];

  buildPhase = ''
    gradle build --no-daemon
  '';

  installPhase = ''
    mkdir -p $out/share/java $out/bin
    cp build/libs/*.jar $out/share/java/
    makeWrapper ${jdk}/bin/java $out/bin/my-app \
      --add-flags "-jar $out/share/java/my-app.jar"
  '';
}
```

**Note**: This approach isn't fully reproducible as Gradle may download dependencies at build time.

## Using makeWrapper for JAVA_HOME

When packaging Java/Kotlin tools, use `makeWrapper` to set `JAVA_HOME`:

```nix
makeWrapper ${jre}/bin/java $out/bin/my-tool \
  --set JAVA_HOME ${jre} \
  --add-flags "-jar $out/share/java/my-tool.jar"
```

This ensures the correct Java version without requiring `patchelf` or FHS environments.

## Java Versions

Specify Java version by choosing the appropriate JDK/JRE:

```nix
buildMavenPackage.override { jdk = pkgs.jdk21; }
```

Available: `jdk` (latest LTS), `jdk21`, `jdk17`, `jdk11`, `jre`, etc.

## Kotlin-Specific Considerations

Kotlin projects work the same as Java:
- **Maven**: Use `buildMavenPackage` (recommended)
- **Gradle**: Pre-built binary wrapping or manual build

Kotlin Language Server example (2025): Packaged using pre-built binary approach with `makeWrapper`.

## Alternative: mvn2nix

For complex Maven projects:

```bash
# Generate Nix expression from pom.xml
mvn2nix
```

This can help handle complex dependency trees.

## Further Reading

- **nixpkgs Maven documentation**: https://github.com/NixOS/nixpkgs/blob/master/doc/languages-frameworks/maven.section.md
- **Maven language guide**: https://ryantm.github.io/nixpkgs/languages-frameworks/maven/
- **Packaging Kotlin LSP (2025)**: https://britter.dev/blog/2025/11/15/kotlin-lsp-nixvim/
- **NixOS + Enterprise Java (2025)**: https://britter.dev/blog/2025/02/27/nix-java-enterprise/
- **Packaging Gradle software**: https://rafael.ovh/posts/packaging-gradle-software-with-nix/
- **mvn2nix tool**: https://discourse.nixos.org/t/mvn2nix-packaging-maven-application-made-easy/8751
