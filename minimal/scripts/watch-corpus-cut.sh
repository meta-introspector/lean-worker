#!/usr/bin/env bash
# Watch the corpus cut; when it exits, cross-check the manifest and log results.
# Launched detached: setsid nohup scripts/watch-corpus-cut.sh >/tmp/cut-watch.log 2>&1 &
set -u
MERGE=/mnt/data1/aristotle-merge
CHECK="$HOME/projects/lean-worker/minimal/scripts/check-cut-manifest.py"
GOKUJO="$HOME/projects/lean-worker/minimal/gokujo"

echo "$(date '+%F %T') watcher started; waiting for cut process..."
while pgrep -f "gokujo(-new)? cut /mnt/data1/aristotle-results" >/dev/null; do
  sleep 60
done
echo "$(date '+%F %T') cut process finished."

if [ -s "$MERGE/cut-manifest.json" ]; then
  echo "$(date '+%F %T') manifest present: $(wc -c < "$MERGE/cut-manifest.json") bytes"
  python3 "$CHECK" "$MERGE/cut-manifest.json" > "$MERGE/cut-manifest.check.log" 2>&1
  rc=$?
  echo "$(date '+%F %T') cross-check exit=$rc (log: $MERGE/cut-manifest.check.log)"
  tail -5 "$MERGE/cut-manifest.check.log"
else
  echo "$(date '+%F %T') ERROR: cut-manifest.json missing or empty"
  echo "cut log tail:"; tail -20 /tmp/cut-corpus.log
fi
echo "$(date '+%F %T') watcher done."
