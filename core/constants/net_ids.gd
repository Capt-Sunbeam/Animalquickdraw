class_name NetIds
## Wire-level enums shared by every peer (skeleton guide §3.7). Values ride
## in RPCs, so ordering is append-only once any build has shipped.

## Round-loop phases (Slice 3 drives; POOL_SETUP = Slice 7, PAUSED = Slice 9).
enum Phase { LOBBY, POOL_SETUP, ROUND_INTRO, DRAWING, REVEAL, JUDGING, RESOLUTION, WRAP_UP, PAUSED }

## Reaction emoji set (brief §11; Slice 4 implements the pipeline).
enum Reaction { LAUGH, LOVE, WOW, DISGUST, CRY, FIRE }
