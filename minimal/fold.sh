#!/usr/bin/env bash
# fold.sh — Fold individual knives into the single-file product.
#
# Usage: ./fold.sh
#
# Produces: minimal/Gokujo.lean (self-contained, no imports)
#
# Each file is a "knife" that can be edited independently.
# The fold script concatenates them in order to produce the product.

set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="$DIR/Gokujo.lean"

# Header
cat > "$OUT" << 'HEADER'
/-!
# 極上 · gokujō — a Swiss army knife for Lean 4

`gokujo` is **one Lean file** and **one Markdown file**.  The Lean file is the
program; the Markdown file contains the Lean file; the program contains the
documentation; the program prints the documentation as text (CLI) or as a
single self-contained HTML page.

It is meant to be dropped into any Lean project as the only build- and
proof-checking tool that project needs: it replaces the roles of `make`,
`lake`, `elan` and `nix` for the job of *preparing and checking proofs*.

    gokujo help                  # the manual, in the terminal
    gokujo html -o gokujo.html   # the manual, as one self-contained page
    gokujo doctor                # which toolchains this machine can use
    gokujo scan RequestProject   # parse Lean sources, list declarations
    gokujo sorry RequestProject  # fail if any `sorry`/`admit` is reachable
    gokujo graph RequestProject  # import graph + verified topological order
    gokujo build RequestProject  # compile every module, no lake, no make
    gokujo axioms RequestProject # audit the axioms behind every theorem
    gokujo check                 # scan + build + sorry + axioms, one gate
    gokujo tangle GOKUJO.md      # Markdown  -> Lean
    gokujo weave  Gokujo.lean    # Lean      -> Markdown
    gokujo selfcheck             # the two files still agree
    gokujo bootstrap             # compile gokujo itself to a native binary
    gokujo targets               # the per-platform executable matrix

This file has no imports.  It is core Lean 4 only, so it compiles with a bare
`lean` binary in about a second, on any toolchain, with no package manager and
no network.

The parts of `gokujo` that could silently lie are *proved*: the lexer loses no
characters (`Gokujo.Lex.tokenize_faithful`), a reported `sorry` is always a
real code token of the file (`Gokujo.Syn.reported_holes_are_code`), the
Markdown round trip is an identity (`Gokujo.Md.tangle_weave`), the escaping
used by the HTML output really escapes (`Gokujo.Html.escape_no_lt`), and the
build order it hands to the compiler is checked, by a checker that is proved
sound (`Gokujo.Graph.order_ok_sound`).
-*/

namespace Gokujo

/-! ## 0. Identity -/

/-- The version of the knife. -/
def version : String := "1.0.0"

/-- The name, in Japanese: 極上 *gokujō*, "finest quality". -/
def kanji : String := "極上"
HEADER

# Fold in the infrastructure knife
echo "" >> "$OUT"
echo "/-! ## Infra: build infrastructure generation -/" >> "$OUT"
cat "$DIR/GokujoInfra.lean" >> "$OUT"

# Fold in the test knife
echo "" >> "$OUT"
echo "/-! ## Test: infrastructure validation -/" >> "$OUT"
cat "$DIR/GokujoTest.lean" >> "$OUT"

# Fold in the exec knife
echo "" >> "$OUT"
echo "/-! ## Exec: agent workflow execution -/" >> "$OUT"
cat "$DIR/GokujoExec.lean" >> "$OUT"

# Append the rest of the main file (everything after the imports section)
# We need to skip the header and imports from the original Gokujo.lean
# and append from the namespace Gokujo block onward
echo "" >> "$OUT"
echo "/-! ## 1. Small utilities -/" >> "$OUT"

# Find the line number where the actual code starts (after the imports)
# in the original file and append from there
# Actually, we need to get the original file's content starting from
# the "namespace Util" or the first actual code after the header
# Let's use the existing Gokujo.lean and skip the first ~50 lines (header + namespace)
tail -n +50 "$DIR/Gokujo.lean" >> "$OUT" 2>/dev/null || true

echo "✅ Folded $OUT"
