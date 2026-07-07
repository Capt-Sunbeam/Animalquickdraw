class_name NetIds
## Wire-level enums shared by every peer (skeleton guide §3.7). Values ride
## in RPCs, so ordering is append-only once any build has shipped.

## Round-loop phases (Slice 3 drives; POOL_SETUP = Slice 7, PAUSED = Slice 9).
enum Phase { LOBBY, POOL_SETUP, ROUND_INTRO, DRAWING, REVEAL, JUDGING, RESOLUTION, WRAP_UP, PAUSED }

## Reaction emoji set (brief §11; Slice 4 implements the pipeline).
enum Reaction { LAUGH, LOVE, WOW, DISGUST, CRY, FIRE }

## Slice 7: why a pool-word submission was rejected. NONE (0) = accepted -
## deliberate deviation from the TDD draft, whose reason enum started at 0
## and collided with OK. LOCKED is drop-tier (never sent over the wire).
enum WordRejectReason { NONE, NOT_CLEAN, BAD_LENGTH, WRONG_COUNT, ALREADY_SUBMITTED, LOCKED }
