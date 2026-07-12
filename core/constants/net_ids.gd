class_name NetIds
## Wire-level enums shared by every peer (skeleton guide §3.7). Values ride
## in RPCs, so ordering is append-only once any build has shipped.

## Round-loop phases (Slice 3 drives; POOL_SETUP = Slice 7, PAUSED = Slice 9).
enum Phase { LOBBY, POOL_SETUP, ROUND_INTRO, DRAWING, REVEAL, JUDGING, RESOLUTION, WRAP_UP, PAUSED }

## Slice 7: why a pool-word submission was rejected. NONE (0) = accepted -
## deliberate deviation from the TDD draft, whose reason enum started at 0
## and collided with OK. LOCKED is drop-tier (never sent over the wire).
enum WordRejectReason { NONE, NOT_CLEAN, BAD_LENGTH, WRONG_COUNT, ALREADY_SUBMITTED, LOCKED }

## Slice 9: why the game is paused (rides in the PAUSED phase data).
## HOST_MENU = Slice 6 Esc-menu pause; BELOW_MINIMUM = roster fell under
## GameConstants.MIN_PLAYERS (auto-resumes when it recovers).
enum PauseReason { HOST_MENU, BELOW_MINIMUM }

## Slice 9: rpc_sync_player_status kind - what happened to the player.
## KICKED appended by Slice 13 (append-only rule above): the host removed
## the player; their platform_id is session-blocklisted against rejoin.
enum PlayerStatus { DROPPED, REJOINED, LATE_JOINED, KICKED }

## Slice 12: network/protocol version, written into Steam lobby metadata
## (aq_proto) and matched exactly by joiners and lobby searches. Bump on ANY
## breaking RPC/payload change; a mismatch reads as "room not found".
const PROTOCOL_VERSION: String = "1"
