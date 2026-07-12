#!/usr/bin/env bash
# Automated two-instance ENet connect check - the scripted equivalent of the
# Chunk 1 blocking playtest gate ("two local instances connect"). Exits 0
# when host and client both report a successful connection.
# Usage: tools/verify_connect.sh [ROOM_CODE]
set -u
CODE="${1:-LOCAL}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-godot}"

"$GODOT" --headless --path "$ROOT" -- --platform=enet --name=CIHost --code="$CODE" --ci-host &
HOST_PID=$!
sleep 3
"$GODOT" --headless --path "$ROOT" -- --platform=enet --name=CIClient --code="$CODE" --ci-join
CLIENT_RC=$?
wait "$HOST_PID"
HOST_RC=$?

echo "host_rc=$HOST_RC client_rc=$CLIENT_RC"
if [ "$HOST_RC" -eq 0 ] && [ "$CLIENT_RC" -eq 0 ]; then
  echo "VERIFY_CONNECT: PASS"
  exit 0
fi
echo "VERIFY_CONNECT: FAIL"
exit 1
