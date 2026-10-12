#!/usr/bin/env bash
set -euo pipefail

# This script builds the Gokujo project using the single file approach
cd "$(dirname "$0")"

echo "Building Gokujo with single-file approach..."

# First, ensure the single file Gokujo.lean exists
if [ ! -f "Gokujo.lean" ]; then
    echo "ERROR: Gokujo.lean not found!"
    exit 1
fi

# Compile the library (both olean for imports and C for linking) and executable
echo "Compiling Gokujo library and native binary..."
lean -o Gokujo.olean -c Gokujo.c Gokujo.lean
lean -c GokujoMain.c GokujoMain.lean
leanc -o gokujo Gokujo.c GokujoMain.c

echo "Build successful!"

# Run help
echo ""
echo "=== gokujo help ==="
./gokujo help
