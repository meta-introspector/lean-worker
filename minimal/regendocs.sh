#!/usr/bin/env bash
set -euo pipefail

# Regenerate documentation and rebuild infrastructure for the core Gokujo project
# Uses the native binary (not lean --run) because the interpreter still has the
# old recursive scanStr from GokujoCore.lean which causes stack overflows.

cd "$(dirname "$0")"

# Build native binary first (has iterative walkLean fix)
echo "=== Building Native Binary (Fixed walkLean) ==="
./gokujo bootstrap -o gokujo --backend system
echo "✓ Native binary rebuilt: gokujo"

echo ""
echo "=== Regenerate Gokujo Documentation ==="
echo "Running 'gokujo html' to generate documentation..."
./gokujo html -o gokujo-docs.html
echo "✓ HTML documentation generated: gokujo-docs.html"

echo ""
echo "=== Regenerate Infrastructure Files ==="
echo "Running 'gokujo infra' to generate build infrastructure..."
./gokujo infra
echo "✓ Infrastructure files generated (lakefile.toml, fast-lakefile.toml, flake.nix, etc.)"

echo ""
echo "=== Verify Infrastructure ==="
echo "Running 'gokujo test' to validate generated files..."
./gokujo test
echo "✓ Infrastructure validation passed"

# Verify the fix works
echo ""
echo "=== Verify Stack Overflow Fix ==="
echo "Running full project scan with native binary..."
./gokujo scan RequestProject 2>&1 | head -5
echo "✓ Full project scan completed (no stack overflow)"

echo ""
echo "=== All Documentation Regenerated Successfully ==="
echo "Files updated: - gokujo-docs.html (manual)"
echo "Files generated: - lakefile.toml, fast-lakefile.toml, flake.nix, .github/workflows/lean.yml, pipelight.yml, Makefile"
echo "Binary rebuilt: - gokujo (with iterative walkLean)"