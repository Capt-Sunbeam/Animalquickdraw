#!/usr/bin/env bash
# Automated Slice 3 round-loop gate - the scripted equivalent of the Chunk 6
# blocking playtest: host + 2 clients play a full 2-round game headless
# (start gate -> intro -> draw/submit -> anonymous reveal -> judge pick ->
# resolution -> no-pick lapse round -> standings). Verifies phase sequences,
# role views, +2/-1 scoring, and the results bundle on every peer.
# Owner playtests remain the formal gate (workflows/testing-protocol.md).
# Usage: tools/verify_round.sh [ROOM_CODE]
# NOTE: takes ~60-80 s real time (the no-pick round waits out the 30 s
# judging window on purpose).
set -u
CODE="${1:-LOCAL}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-godot}"

"$GODOT" --headless --path "$ROOT" -- --platform=enet --name=CIHost --code="$CODE" --ci-round-host &
HOST_PID=$!
sleep 3
"$GODOT" --headless --path "$ROOT" -- --platform=enet --name=CIJoinB --code="$CODE" --ci-round-join &
B_PID=$!
sleep 1
"$GODOT" --headless --path "$ROOT" -- --platform=enet --name=CIJoinC --code="$CODE" --ci-round-join
C_RC=$?
wait "$B_PID"; B_RC=$?
wait "$HOST_PID"; HOST_RC=$?

echo "host_rc=$HOST_RC joinB_rc=$B_RC joinC_rc=$C_RC"
if [ "$HOST_RC" -eq 0 ] && [ "$B_RC" -eq 0 ] && [ "$C_RC" -eq 0 ]; then
  echo "VERIFY_ROUND: PASS"
  exit 0
fi
echo "VERIFY_ROUND: FAIL"
exit 1
