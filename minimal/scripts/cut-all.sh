#!/usr/bin/env bash
# cut-all.sh — run `gokujo cut` once per project under CORPUS, isolating
# failures: a project that crashes (e.g. a stack overflow on a pathological
# file) is logged and skipped, never killing the whole corpus run.
#
# Usage: cut-all.sh CORPUS OUTDIR [GOKUJO]
# Writes OUTDIR/<project>.json per project, failures.log, and at the end
# merges everything into OUTDIR/cut-manifest.json.
set -u
CORPUS=${1:?corpus root}
OUTDIR=${2:?output dir}
GOKUJO=${3:-$HOME/projects/lean-worker/minimal/gokujo}
MERGE="$HOME/projects/lean-worker/minimal/scripts/merge-cut-manifests.py"

mkdir -p "$OUTDIR"
: > "$OUTDIR/failures.log"

n=0
total=$(ls -d "$CORPUS"/*/ 2>/dev/null | wc -l)
for d in "$CORPUS"/*/; do
  name=$(basename "$d")
  n=$((n + 1))
  if [ -s "$OUTDIR/$name.json" ]; then
    continue   # already done (resumable)
  fi
  if "$GOKUJO" cut "$d" -o "$OUTDIR/$name.json" >/dev/null 2>&1; then
    echo "$(date '+%T') [$n/$total] ok   $name"
  else
    echo "$(date '+%T') [$n/$total] FAIL $name" | tee -a "$OUTDIR/failures.log"
  fi
done

echo "merging into $OUTDIR/cut-manifest.json"
python3 "$MERGE" "$OUTDIR" "$OUTDIR/cut-manifest.json"
echo "done; failures: $(wc -l < "$OUTDIR/failures.log")"
