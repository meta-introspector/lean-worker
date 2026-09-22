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

# Compile the library first
echo "Compiling Gokujo.lean as library..."
lean -o Gokujo.olean Gokujo.lean

# Compile the single file executable
echo "Compiling GokujoMain.lean..."
lean -R . -o gokujo GokujoMain.lean

echo "Build successful!"

# Run help
echo ""
echo "=== gokujo help ==="
./gokujo help
