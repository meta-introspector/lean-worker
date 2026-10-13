#!/usr/bin/env bash
# PB-22 live test against the deployed worker.
#
# The prototype passed post 1, 2 and 3 with invites aaaaaaaa / bbbbbbbb /
# aaaaaaaa and answered ok:true to all three. This asserts post 2 is now a 403
# and that cursors advance and reads return lines, which is the assertion the
# prototype could not satisfy at all.
set -u
BASE="${1:-https://otc-desk-relay-v2.jmikedupont2.workers.dev}"
ROOM="pb22-live-$(date +%s)-$$"
pass=0; fail=0

chk() { # chk <name> <expected> <actual>
  if [ "$2" = "$3" ]; then echo "  ok    $1"; pass=$((pass+1));
  else echo "  FAIL  $1 (expected $2, got $3)"; fail=$((fail+1)); fi
}

post() { # post <invite> <body> <peer>
  curl -sS -o /tmp/pb22.body -w '%{http_code}' -X POST "$BASE/room/$ROOM" \
    -H "content-type: text/plain" -H "invite-token: $1" -H "peer-id: $3" \
    --data-raw "$2"
}

echo "target: $BASE"
echo "room:   $ROOM"
echo
echo "health"
code=$(curl -sS -o /tmp/pb22.health -w '%{http_code}' "$BASE/health")
chk "/health answers 200" 200 "$code"
grep -q '"inviteEnforced":true' /tmp/pb22.health && { echo "  ok    inviteEnforced is reported true"; pass=$((pass+1)); } \
  || { echo "  FAIL  inviteEnforced is not true"; fail=$((fail+1)); }
grep -q 'durable-object' /tmp/pb22.health && { echo "  ok    health reports durable-object state"; pass=$((pass+1)); } \
  || { echo "  FAIL  health does not mention a durable object"; fail=$((fail+1)); }

echo
echo "the old bypass"
code=$(post aaaaaaaa one p1); chk "post 1 with aaaaaaaa is accepted" 200 "$code"
c1=$(grep -o '"cursor":[0-9]*' /tmp/pb22.body | head -1 | cut -d: -f2)
chk "post 1 cursor is 1" 1 "$c1"

code=$(post bbbbbbbb intruder p2); chk "post 2 with bbbbbbbb is refused" 403 "$code"
grep -q '"type":"invite_invalid"' /tmp/pb22.body && { echo "  ok    refused as invite_invalid"; pass=$((pass+1)); } \
  || { echo "  FAIL  refusal was not invite_invalid: $(cat /tmp/pb22.body)"; fail=$((fail+1)); }

code=$(post aaaaaaaa three p1); chk "post 3 with aaaaaaaa is accepted" 200 "$code"
c3=$(grep -o '"cursor":[0-9]*' /tmp/pb22.body | head -1 | cut -d: -f2)
chk "post 3 cursor is 2 (the refused post left nothing)" 2 "$c3"

echo
echo "state is readable, which the prototype never managed"
code=$(curl -sS -o /tmp/pb22.get -w '%{http_code}' "$BASE/room/$ROOM?peer=p1" -H "invite-token: aaaaaaaa")
chk "GET with a valid invite answers 200" 200 "$code"
chk "GET returns both accepted lines" '["one","three"]' "$(grep -o '"lines":\[[^]]*\]' /tmp/pb22.get | cut -d: -f2-)"
chk "GET cursor is 2" 2 "$(grep -o '"cursor":[0-9]*' /tmp/pb22.get | head -1 | cut -d: -f2)"

code=$(curl -sS -o /tmp/pb22.get2 -w '%{http_code}' "$BASE/room/$ROOM?peer=p1&cursor=1" -H "invite-token: aaaaaaaa")
chk "GET from cursor 1 returns only the tail" '["three"]' "$(grep -o '"lines":\[[^]]*\]' /tmp/pb22.get2 | cut -d: -f2-)"

echo
echo "reads are gated too"
code=$(curl -sS -o /dev/null -w '%{http_code}' "$BASE/room/$ROOM?peer=stranger-$$")
chk "GET with no invite is refused" 403 "$code"
code=$(curl -sS -o /dev/null -w '%{http_code}' "$BASE/room/$ROOM?peer=stranger2-$$" -H "invite-token: bbbbbbbb")
chk "GET with the wrong invite is refused" 403 "$code"

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]