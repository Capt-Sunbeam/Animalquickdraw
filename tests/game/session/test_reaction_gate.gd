class_name TestReactionGate
extends GdUnitTestSuite
## Gate lifecycle + close grace (Slice 4 TDD §5/§10) with an injected clock.

var _fake_now_ms: int = 50000


func _now_ms() -> int:
	return _fake_now_ms


func _make_gate() -> ReactionGate:
	return ReactionGate.new(Callable(self, "_now_ms"))


func test_closed_by_default() -> void:
	assert_bool(_make_gate().is_open_for("d1")).is_false()


func test_open_all_accepts_only_listed_ids() -> void:
	var gate: ReactionGate = _make_gate()
	gate.open_all(PackedStringArray(["d1", "d2"]))
	assert_bool(gate.is_open_for("d1")).is_true()
	assert_bool(gate.is_open_for("d2")).is_true()
	assert_bool(gate.is_open_for("d3")).is_false()


func test_open_for_subset_replaces_previous_set() -> void:
	var gate: ReactionGate = _make_gate()   # Slice 5 reveal beats
	gate.open_for(PackedStringArray(["d1"]))
	gate.open_for(PackedStringArray(["d2"]))
	assert_bool(gate.is_open_for("d1")).is_false()
	assert_bool(gate.is_open_for("d2")).is_true()


func test_close_grace_window_accepts_then_drops() -> void:
	var gate: ReactionGate = _make_gate()
	gate.open_all(PackedStringArray(["d1"]))
	gate.close()
	# Inside the grace window the racing request still counts (§10).
	_fake_now_ms += GameConstants.REACTION_CLOSE_GRACE_MSEC
	assert_bool(gate.is_open_for("d1")).is_true()
	# One ms past the grace: dropped.
	_fake_now_ms += 1
	assert_bool(gate.is_open_for("d1")).is_false()


func test_reopen_after_close_clears_grace() -> void:
	var gate: ReactionGate = _make_gate()
	gate.open_all(PackedStringArray(["d1"]))
	gate.close()
	gate.open_all(PackedStringArray(["d2"]))
	assert_bool(gate.is_open_for("d2")).is_true()
	_fake_now_ms += GameConstants.REACTION_CLOSE_GRACE_MSEC + 1
	assert_bool(gate.is_open_for("d2")).is_true()   # open has no expiry
