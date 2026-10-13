#!/usr/bin/env bash
# scp-quarantine.sh — Secure. Contain. Protect.
#
# Policy: the launchpad does not debug, it contains. A source that exceeds
# the knife's budget (stack overflow, watchdog timeout) is not a bug to fix
# right now — it is contraband: logged to the PHASE2 ledger and processed
# in phase 2. Healthy files never pay for their neighbours.
#
# Field knowledge baked in (learned the hard way):
#   * Two distinct crash classes exist:
#       - lake-walk:  <project>/.lake/packages/* are symlinks into the shared
#         lake cache (mathlib et al.); the knife follows symlinks when walking
#         a project dir, walks all of Mathlib, and dies. Labs built from the
#         project's OWN .lean files (find never descends into symlinked dirs,
#         and we prune */.lake/* explicitly) are immune by construction.
#       - file-budget: a single pathological file (deep comment nesting etc.)
#         overflows the knife on its own; per-file bisect isolates it.
#   * Namespace discipline: subset list files live in $LAB/l/<ID>, lab dirs
#     in $LAB/d/<ID>, JSON outputs in $LAB/d/<ID>.json — nothing ever shares
#     a name, or `head -n $half list.a > list.a` becomes a directory and the
#     whole bisect silently degrades to empty lists (v1 bug, 29 garbage
#     manifests).
#   * IDs are stable per real file via `stat -c %i` (inode) — no re-quarantine
#     of the same file reached through different subset splits, no bash
#     string-hashing.
#   * Every command that reads a list reads it with an explicit redirect, and
#     every knife call gets </dev/null — a stray shared stdin once made `wc`
#     eat the main loop's position.
#
# Usage: scp-quarantine.sh CORPUS CUTPARTS PHASE2 [BUDGET_SECONDS]
#   After it finishes, re-run cut-all.sh: rescued projects now have their
#   <name>.json and are skipped on resume; the merge then covers everything.
set -u
CORPUS=${1:?corpus root}
CUTPARTS=${2:?cut-parts dir (has failures.log)}
PHASE2=${3:?phase2 output dir}
BUDGET=${4:-300}
MAX_DEPTH=${MAX_DEPTH:-24}
GOKUJO=${GOKUJO:-$HOME/projects/lean-worker/minimal/gokujo}

FAILLOG="${FAILLOG:-$CUTPARTS/failures.log}"   # override for parallel slices
[ -s "$FAILLOG" ] || { echo "no failures in $FAILLOG — nothing to contain"; exit 0; }

LEDGER="$PHASE2/ledger.jsonl"
SUMMARY="$PHASE2/summary.json"
mkdir -p "$PHASE2"
touch "$LEDGER"
LAB=$(mktemp -d /tmp/scp-lab.XXXXXX)
mkdir -p "$LAB/l" "$LAB/d"
trap 'rm -rf "$LAB"' EXIT

# per-project counters (globals; scp_partition is not reentered concurrently)
R_TOTAL=0; Q_TOTAL=0; LABEL=""
CID=0   # subset id counter

fold_rescue() {
  python3 - "$1" "$LAB/rescue.json" <<'PYEOF'
import json, sys
sub, acc = json.load(open(sys.argv[1])), json.load(open(sys.argv[2]))
p = sub["projects"][0]
for k in ("files", "unique_files", "modules", "decls", "holes"):
    acc[k] = acc.get(k, 0) + p.get(k, 0)
acc["obligations"] = acc.get("obligations", []) + p.get("obligations", [])
json.dump(acc, open(sys.argv[2], "w"))
PYEOF
}

quarantine() {
  local f=$1 rc=$2 reason fid
  fid=$(stat -c %i "$f" 2>/dev/null || echo "x$RANDOM")
  case "$rc" in
    124) reason="budget-timeout" ;;
    134|136|139) reason="crash-signal-$rc" ;;
    90) reason="depth-limit-block" ;;
    *) reason="exit-$rc" ;;
  esac
  printf '{"ts":"%s","project":"%s","file":"%s","inode":"%s","bytes":%s,"lines":%s,"exit":%s,"reason":"%s","phase":2}\n' \
    "$(date -u +%FT%TZ)" "$LABEL" "$f" "$fid" \
    "$(stat -c %s "$f" 2>/dev/null || echo 0)" \
    "$(wc -l < "$f" 2>/dev/null || echo 0)" "$rc" "$reason" >> "$LEDGER"
  Q_TOTAL=$((Q_TOTAL + 1))
  echo "  QUARANTINE $reason: $(basename "$f")"
}

# scp_partition ID DEPTH — bisect the subset in $LAB/l/$ID.
scp_partition() {
  local id=$1 depth=$2 n half i=0 f rc
  n=$(wc -l < "$LAB/l/$id")
  [ "$n" -eq 0 ] && return 0

  local dir="$LAB/d/$id"
  mkdir -p "$dir"
  while IFS= read -r f; do
    i=$((i + 1)); ln -sf "$f" "$dir/f$i.lean"
  done < "$LAB/l/$id"

  timeout "$BUDGET" "$GOKUJO" cut "$dir" -o "$LAB/d/$id.json" >/dev/null 2>&1 </dev/null
  rc=$?

  if [ "$rc" -eq 0 ]; then
    fold_rescue "$LAB/d/$id.json"
    R_TOTAL=$((R_TOTAL + n))
    return 0
  fi

  if [ "$n" -eq 1 ]; then
    f=$(head -n 1 "$LAB/l/$id")
    quarantine "$f" "$rc"
    return 0
  fi

  if [ "$depth" -ge "$MAX_DEPTH" ]; then
    echo "  DEPTH LIMIT ($MAX_DEPTH): quarantining $n-file block"
    while IFS= read -r f; do quarantine "$f" 90; done < "$LAB/l/$id"
    return 0
  fi

  half=$((n / 2))
  CID=$((CID + 1)); local a="L$CID"
  CID=$((CID + 1)); local b="L$CID"
  head -n "$half" "$LAB/l/$id" > "$LAB/l/$a"
  tail -n "+$((half + 1))" "$LAB/l/$id" > "$LAB/l/$b"
  scp_partition "$a" $((depth + 1))
  scp_partition "$b" $((depth + 1))
}

: > "$PHASE2/projects.tsv"   # project<TAB>rescued<TAB>quarantined
P_TOTAL=0
N_FAIL=$(awk '/FAIL /{n++} END{print n+0}' "$FAILLOG")
echo "SCP: $N_FAIL failed projects to contain (budget ${BUDGET}s, depth $MAX_DEPTH)"

while IFS= read -r line; do
  case "$line" in *"FAIL "*) ;; *) continue ;; esac
  name=$(printf '%s' "$line" | awk '{print $NF}')
  [ -n "$name" ] || continue
  [ -d "$CORPUS/$name" ] || { echo "skip (no dir): $name"; continue; }

  LABEL=$name
  echo "=== $name ==="
  echo '{}' > "$LAB/rescue.json"
  R_TOTAL=0; Q_TOTAL=0
  # trailing slash matters: find will not descend into a symlinked project
  # dir without it (and -L would over-follow into the lake cache).
  # Prune .lake explicitly for symlink-free projects whose deps live there.
  find "$CORPUS/$name/" -name '*.lean' -not -path '*/.lake/*' | sort > "$LAB/l/ROOT"
  P_TOTAL=$((P_TOTAL + $(wc -l < "$LAB/l/ROOT")))

  scp_partition ROOT 0

  printf '%s\t%s\t%s\n' "$name" "$R_TOTAL" "$Q_TOTAL" >> "$PHASE2/projects.tsv"
  # Always write the rescue manifest (even all-quarantined: empty counters,
  # no obligations) so cut-all.sh sees <name>.json and never re-crashes on
  # this project during its resume pass.
  python3 - "$LAB/rescue.json" "$CUTPARTS/$name.json" "$name" <<'PYEOF'
import json, sys
acc = json.load(open(sys.argv[1]))
proj = {"name": sys.argv[3], **acc}
out = {"gokujo": "1.0.0", "kind": "cut-manifest", "projects": [proj],
       "total": {"projects": 1, **{k: v for k, v in acc.items() if k != "obligations"}}}
json.dump(out, open(sys.argv[2], "w"))
PYEOF
  if [ "$R_TOTAL" -gt 0 ]; then
    echo "  RESCUED $R_TOTAL files (manifest: $name.json)"
  else
    echo "  FULLY QUARANTINED: all files over budget (manifest: $name.json)"
  fi
  echo "  score: rescued=$R_TOTAL quarantined=$Q_TOTAL"
done < "$FAILLOG"

Q_LINES=$(wc -l < "$LEDGER")
python3 - "$PHASE2/projects.tsv" "$SUMMARY" "$P_TOTAL" "$Q_LINES" <<'PYEOF'
import json, sys
rows = [l.rstrip("\n").split("\t") for l in open(sys.argv[1]) if l.strip()]
summary = {
    "policy": "SCP: over-budget sources are quarantined to phase 2, not debugged in phase 1",
    "projects": {r[0]: {"rescued": int(r[1]), "quarantined": int(r[2])} for r in rows},
    "total_files_seen": int(sys.argv[3]),
    "total_quarantined": int(sys.argv[4]),
}
json.dump(summary, open(sys.argv[2], "w"), indent=1)
PYEOF
echo "SCP done: $Q_LINES file(s) in $LEDGER; summary in $SUMMARY"
