class_name TestAvatarValidation
extends GdUnitTestSuite
## Slice 11 (TDD §11): host-side avatar validation as a plain function
## (consistency guide §9 - no live network needed). The RPC handler drops
## silently on any non-empty reason.


func _valid_doc(op_count: int = 1) -> Dictionary:
	var ops: Array = []
	for i: int in range(op_count):
		ops.append({"t": "fill", "c": 17, "x": 100, "y": 100 + (i % 400)})
	return {"v": 1, "orientation": "avatar", "ops": ops}


func test_accepts_a_typical_valid_avatar_doc() -> void:
	assert_str(SessionRules.avatar_doc_error(_valid_doc(5))).is_empty()


func test_rejects_oversized_payload() -> void:
	var pts: Array = []
	var ts: Array = []
	for i: int in range(4000):
		pts.append(float(i % 512))
		pts.append(float((i * 7) % 512))
		ts.append(float(i) * 0.01)
	var doc: Dictionary = {"v": 1, "orientation": "avatar", "ops": [
		{"t": "stroke", "c": 4, "s": 1, "pts": pts, "ts": ts},
	]}
	assert_str(SessionRules.avatar_doc_error(doc)).is_equal("oversized")


func test_rejects_wrong_orientation() -> void:
	assert_str(SessionRules.avatar_doc_error({"v": 1, "orientation": "landscape",
			"ops": [{"t": "clear"}]})).is_equal("wrong_orientation")


func test_rejects_too_many_ops() -> void:
	var ops: Array = []
	for i: int in range(GameConstants.AVATAR_MAX_OPS + 1):
		ops.append({"t": "clear"})
	assert_str(SessionRules.avatar_doc_error({"v": 1, "orientation": "avatar",
			"ops": ops})).is_equal("too_many_ops")


func test_rejects_malformed_and_empty_docs() -> void:
	assert_str(SessionRules.avatar_doc_error({})).is_equal("malformed")
	assert_str(SessionRules.avatar_doc_error({"v": 1, "orientation": "avatar",
			"ops": [{"t": "mystery"}]})).is_equal("malformed")
	assert_str(SessionRules.avatar_doc_error({"v": 1, "orientation": "avatar",
			"ops": []})).is_equal("empty")
