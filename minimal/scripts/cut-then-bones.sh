#!/usr/bin/env bash
# Unattended chain: wait for the corpus cut to finish → cross-check the
# manifest → emit bones for all projects → leave the aggregate summary.
# Launched detached (setsid nohup … >/tmp/chain.log 2>&1 </dev/null & disown).
set -u
MERGE=/mnt/data1/aristotle-merge
MINIMAL="$HOME/projects/lean-worker/minimal"
CHECK="$MINIMAL/scripts/check-cut-manifest.py"
BONES="$MINIMAL/scripts/emit-bones.py"
CORPUS=/mnt/data1/aristotle-results

echo "$(date '+%F %T') chain started"
# 1. wait for the running cut (poll every 2 min, give up after 12 h)
for i in $(seq 1 360); do
  pgrep -f "gokujo(-new)? cut /mnt/data1/aristotle-results" >/dev/null || break
  sleep 120
done
if pgrep -f "gokujo(-new)? cut /mnt/data1/aristotle-results" >/dev/null; then
  echo "$(date '+%F %T') GIVE UP: cut still running after 12 h"; exit 1
fi
echo "$(date '+%F %T') cut finished"
[ -s "$MERGE/cut-manifest.json" ] || { echo "manifest missing"; exit 1; }

# 2. cross-check
python3 "$CHECK" "$MERGE/cut-manifest.json" > "$MERGE/cut-manifest.check.log" 2>&1
echo "$(date '+%F %T') cross-check exit=$?"
grep -E "PASS|FAIL" "$MERGE/cut-manifest.check.log" | tail -1

# 3. bones for the whole corpus (single cache load), aggregate included
python3 "$BONES" "$CORPUS" --all --out "$MERGE/bones" > "$MERGE/bones-all.log" 2>&1
echo "$(date '+%F %T') bones-all exit=$?"
tail -3 "$MERGE/bones-all.log"

# 4. final summary
if [ -f "$MERGE/bones/ALL/summary.json" ]; then
  echo "$(date '+%F %T') corpus totals:"; cat "$MERGE/bones/ALL/summary.json"
fi
echo "$(date '+%F %T') chain done"
