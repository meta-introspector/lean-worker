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

# Compile the single file
echo "Compiling Gokujo.lean..."
lean --run Gokujo.lean help

echo "Build successful!"
