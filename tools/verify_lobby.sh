#!/usr/bin/env bash
# Automated Slice 2 lobby gate check - the scripted equivalent of the
# Chunk 4 blocking playtests: (a) host + 2 clients converge on one 3-player
# roster, a blocklisted chat probe arrives censored everywhere, and the
# start gate broadcast reaches every peer with the frozen snapshot;
# (b) joining a dead room code fails back to the menu cleanly.
# Owner playtests remain the formal gate (workflows/testing-protocol.md).
# Usage: tools/verify_lobby.sh [ROOM_CODE]
set -u
CODE="${1:-LOCAL}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-godot}"

echo "--- part 1: 3-instance roster/chat/start ---"
"$GODOT" --headless --path "$ROOT" -- --platform=enet --name=CIHost --code="$CODE" --ci-lobby-host --expect=3 &
HOST_PID=$!
sleep 3
"$GODOT" --headless --path "$ROOT" -- --platform=enet --name=CIJoinB --code="$CODE" --ci-lobby-join --expect=3 &
B_PID=$!
sleep 1
"$GODOT" --headless --path "$ROOT" -- --platform=enet --name=CIJoinC --code="$CODE" --ci-lobby-join --expect=3
C_RC=$?
wait "$B_PID"; B_RC=$?
wait "$HOST_PID"; HOST_RC=$?

echo "--- part 2: join-by-dead-code recovers ---"
# LOCAL9 has no host; the client must land back on the menu cleanly.
"$GODOT" --headless --path "$ROOT" -- --platform=enet --name=CIJoinFail --code=LOCAL9 --ci-lobby-join-fail
FAIL_RC=$?

echo "host_rc=$HOST_RC joinB_rc=$B_RC joinC_rc=$C_RC joinfail_rc=$FAIL_RC"
if [ "$HOST_RC" -eq 0 ] && [ "$B_RC" -eq 0 ] && [ "$C_RC" -eq 0 ] && [ "$FAIL_RC" -eq 0 ]; then
  echo "VERIFY_LOBBY: PASS"
  exit 0
fi
echo "VERIFY_LOBBY: FAIL"
exit 1
