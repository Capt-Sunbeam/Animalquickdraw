class_name RoundRecord
extends RefCounted
## Host-only archive of one round (Slice 3 TDD §2); feeds the SessionResults
## bundle at WRAP_UP.

var round_index: int = 0
var judge_player_id: String = ""
var prompt: Prompt = null
var submissions: Array[Submission] = []
var winner_drawing_id: String = ""   # empty = no pick
var winner_player_id: String = ""    # empty = no pick
## Slice 10: drawing ids in on-screen reveal order (the post-shuffle entry
## order) - the superlative tie-break key (§2: earlier reveal wins).
var reveal_order: PackedStringArray = PackedStringArray()


func to_result_dict() -> Dictionary:
	return {
		"round_index": round_index,
		"judge_player_id": judge_player_id,
		"prompt_text": prompt.display_text if prompt != null else "",
		"winner_player_id": winner_player_id,
		"winner_drawing_id": winner_drawing_id,
		"picked": not winner_drawing_id.is_empty(),
	}
