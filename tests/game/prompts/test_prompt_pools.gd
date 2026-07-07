class_name TestPromptPools
extends GdUnitTestSuite
## Slice 3: data-driven prompt engine (TDD §11). Fixture pools (2x2) live in
## tests/fixtures/prompts/; the real ~100-word content gets its own sanity
## checks at the bottom.

const FIXTURE_DIR: String = "res://tests/fixtures/prompts/"


func _fixture_pools(seed_value: int = 1234) -> PromptPools:
	var pools := PromptPools.new()
	pools.rng.seed = seed_value
	pools.load_from(FIXTURE_DIR)
	return pools


func test_fixture_pools_load_and_report_ready() -> void:
	var pools: PromptPools = _fixture_pools()
	assert_bool(pools.is_ready()).is_true()
	assert_int(pools.pool_size("animals")).is_equal(2)
	assert_int(pools.pool_size("adjectives")).is_equal(2)


func test_missing_content_reports_not_ready() -> void:
	var pools := PromptPools.new()
	pools.load_from("res://tests/fixtures/does_not_exist/")
	assert_bool(pools.is_ready()).is_false()


func test_pool_type_parses_draws_and_template() -> void:
	var pools: PromptPools = _fixture_pools()
	var type: PoolType = pools.get_type("animal_adjective")
	assert_object(type).is_not_null()
	assert_str(type.display_name).is_equal("Animal + Adjective")
	assert_int(type.draws.size()).is_equal(2)
	assert_str(str(type.draws[0]["pool"])).is_equal("adjectives")
	assert_int(int(type.draws[0]["count"])).is_equal(1)
	assert_int(type.total_draw_count()).is_equal(2)
	assert_str(type.template).is_equal("{0} {1}")


func test_draw_prompt_composes_template_in_declared_order() -> void:
	var pools: PromptPools = _fixture_pools()
	var type: PoolType = pools.get_type("animal_adjective")
	var prompt: Prompt = pools.draw_prompt(type)
	assert_int(prompt.parts.size()).is_equal(2)
	# Declared draw order: adjective first, animal second.
	assert_array(["sleepy", "grumpy"]).contains([prompt.parts[0]])
	assert_array(["cat", "dog"]).contains([prompt.parts[1]])
	assert_str(prompt.display_text).is_equal("%s %s" % [prompt.parts[0], prompt.parts[1]])
	assert_str(prompt.pool_type_id).is_equal("animal_adjective")


func test_combo_key_stable_for_same_parts() -> void:
	var pools: PromptPools = _fixture_pools()
	var type: PoolType = pools.get_type("animal_adjective")
	var parts := PackedStringArray(["sleepy", "cat"])
	var a: Prompt = Prompt.make(type, parts)
	var b: Prompt = Prompt.make(type, parts)
	assert_str(a.combo_key).is_equal(b.combo_key)
	assert_str(a.combo_key).is_equal("animal_adjective:sleepy|cat")


func test_no_exact_combo_repeat_within_session() -> void:
	var pools: PromptPools = _fixture_pools()
	var type: PoolType = pools.get_type("animal_adjective")
	# 2x2 fixture = exactly 4 combos; draw all 4 without a repeat.
	var seen: Dictionary = {}
	for i: int in range(4):
		var prompt: Prompt = pools.draw_prompt(type)
		assert_bool(seen.has(prompt.combo_key)).is_false()
		seen[prompt.combo_key] = true
	assert_int(seen.size()).is_equal(4)


func test_repeat_allowed_with_warning_after_max_attempts() -> void:
	var pools: PromptPools = _fixture_pools()
	var type: PoolType = pools.get_type("animal_adjective")
	for i: int in range(4):
		pools.draw_prompt(type)
	# Combo space exhausted: the 5th draw must still return a prompt
	# (repeat allowed - never stall the round).
	var fifth: Prompt = pools.draw_prompt(type)
	assert_object(fifth).is_not_null()
	assert_str(fifth.display_text).is_not_empty()


func test_future_pool_type_two_draws_same_pool_works() -> void:
	var pools: PromptPools = _fixture_pools()
	var type: PoolType = pools.get_type("animal_hybrid")
	var prompt: Prompt = pools.draw_prompt(type)
	assert_int(prompt.parts.size()).is_equal(2)
	# Sampling within one draw spec is without replacement.
	assert_str(prompt.parts[0]).is_not_equal(prompt.parts[1])
	assert_str(prompt.display_text).is_equal("%s-%s hybrid" % [prompt.parts[0], prompt.parts[1]])


# --- Real built-in content sanity (implementation checklist task) ---


func test_builtin_content_loads_ready_with_sane_pools() -> void:
	var pools := PromptPools.new()
	pools.load_builtin()
	assert_bool(pools.is_ready()).is_true()
	assert_object(pools.get_type(SettingsDefaults.DEFAULT_POOL_TYPE_ID)).is_not_null()
	assert_int(pools.pool_size("animals")).is_greater_equal(90)
	assert_int(pools.pool_size("adjectives")).is_greater_equal(90)


func test_builtin_content_has_no_empty_or_duplicate_words() -> void:
	for pool_file: String in ["animals", "adjectives"]:
		var raw: String = FileAccess.get_file_as_string(
				"res://game/prompts/data/%s.json" % pool_file)
		var parsed: Dictionary = JSON.parse_string(raw)
		var seen: Dictionary = {}
		for w: Variant in parsed["words"]:
			var word: String = str(w).strip_edges().to_lower()
			assert_str(word).is_not_empty()
			assert_bool(seen.has(word))\
					.override_failure_message("duplicate word '%s' in %s" % [word, pool_file])\
					.is_false()
			seen[word] = true
