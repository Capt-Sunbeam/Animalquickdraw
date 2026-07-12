#!/usr/bin/env bash
# Automated Slice 9 connectivity gate - the scripted equivalent of the
# Chunk 12 blocking playtests: host + 2 clients start a 1-round game; one
# client quits mid-DRAWING (below-minimum pause on the remaining peers),
# rejoins (auto-resume, frozen timer restored, rejoiner sits the round
# out), and its kept submission wins (+2 to the remembered score). Verifies
# per-role phase sequences, pause/resume events, and the wrap-up contract
# keys on every peer. Owner playtests remain the formal gate
# (workflows/testing-protocol.md).
# Usage: tools/verify_resilience.sh [ROOM_CODE]   (~35 s)
set -u
CODE="${1:-LOCAL}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-godot}"

"$GODOT" --headless --path "$ROOT" -- --platform=enet --name=CIHost --code="$CODE" --ci-res-host &
HOST_PID=$!
sleep 3
"$GODOT" --headless --path "$ROOT" -- --platform=enet --name=CIStay --code="$CODE" --ci-res-stay &
STAY_PID=$!
sleep 1
"$GODOT" --headless --path "$ROOT" -- --platform=enet --name=CILeaver --code="$CODE" --ci-res-leaver
LEAVER_RC=$?
wait "$STAY_PID"; STAY_RC=$?
wait "$HOST_PID"; HOST_RC=$?

echo "host_rc=$HOST_RC stay_rc=$STAY_RC leaver_rc=$LEAVER_RC"
if [ "$HOST_RC" -eq 0 ] && [ "$STAY_RC" -eq 0 ] && [ "$LEAVER_RC" -eq 0 ]; then
  echo "VERIFY_RESILIENCE: PASS"
  exit 0
fi
echo "VERIFY_RESILIENCE: FAIL"
exit 1
