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


# --- Slice 7: custom sources, without-replacement draws, silent backfill ---


func _custom_animal_words(n: int) -> PackedStringArray:
	var words := PackedStringArray()
	for i: int in range(n):
		words.append("beast%02d" % i)
	return words


func test_custom_draw_without_replacement_consumes_words() -> void:
	var pools: PromptPools = _fixture_pools()
	var type: PoolType = pools.get_type("animal_adjective")
	pools.set_custom_source("animals", PackedStringArray(["heron", "newt"]))
	pools.set_custom_source("adjectives", PackedStringArray(["shiny", "bored"]))
	var seen_animals: Dictionary = {}
	for i: int in range(2):
		var prompt: Prompt = pools.draw_prompt(type)
		seen_animals[prompt.parts[1]] = true
	# Both custom animals drawn exactly once; both lists fully consumed.
	assert_array(seen_animals.keys()).contains_exactly_in_any_order(["heron", "newt"])
	assert_int((pools._custom_sources["animals"] as Array).size()).is_equal(0)
	assert_int((pools._custom_sources["adjectives"] as Array).size()).is_equal(0)


func test_surplus_words_never_drawn() -> void:
	# 16 custom words, 14 draws -> exactly 2 custom words remain undrawn (§8).
	var pools: PromptPools = _fixture_pools()
	var type: PoolType = pools.get_type("animal_adjective")
	pools.set_custom_source("animals", _custom_animal_words(16))
	var adjectives := PackedStringArray()
	for i: int in range(16):
		adjectives.append("adj%02d" % i)
	pools.set_custom_source("adjectives", adjectives)
	for i: int in range(14):
		pools.draw_prompt(type)
	assert_int((pools._custom_sources["animals"] as Array).size()).is_equal(2)
	assert_int((pools._custom_sources["adjectives"] as Array).size()).is_equal(2)


func test_backfill_from_builtin_when_custom_exhausted() -> void:
	var pools: PromptPools = _fixture_pools()
	var type: PoolType = pools.get_type("animal_adjective")
	pools.set_custom_source("animals", PackedStringArray(["heron"]))
	pools.set_custom_source("adjectives", PackedStringArray(["shiny"]))
	var first: Prompt = pools.draw_prompt(type)
	assert_str(first.parts[0]).is_equal("shiny")
	assert_str(first.parts[1]).is_equal("heron")
	# Custom exhausted: the next draw silently comes from the built-in
	# fixture pools - a valid prompt, indistinguishable in shape.
	var second: Prompt = pools.draw_prompt(type)
	assert_array(["sleepy", "grumpy"]).contains([second.parts[0]])
	assert_array(["cat", "dog"]).contains([second.parts[1]])


func test_backfill_is_silent_no_marker_in_prompt() -> void:
	var pools: PromptPools = _fixture_pools()
	var type: PoolType = pools.get_type("animal_adjective")
	pools.set_custom_source("animals", PackedStringArray([]))   # instantly short
	var prompt: Prompt = pools.draw_prompt(type)
	# Prompt carries no source field by construction - assert the whole
	# public surface so a future "backfilled" flag would fail here.
	assert_str(prompt.pool_type_id).is_equal("animal_adjective")
	assert_int(prompt.parts.size()).is_equal(2)
	assert_str(prompt.display_text).is_not_empty()
	assert_str(prompt.combo_key).is_not_empty()
	var props: Array[String] = []
	for p: Dictionary in prompt.get_property_list():
		if int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			props.append(str(p["name"]))
	assert_array(props).contains_exactly_in_any_order(
			["pool_type_id", "parts", "display_text", "combo_key"])


func test_combo_no_repeat_across_custom_and_backfill_mix() -> void:
	var pools: PromptPools = _fixture_pools()
	var type: PoolType = pools.get_type("animal_adjective")
	# One custom word per pool: draw 1 is fully custom, draw 2 is fully
	# backfilled - the no-repeat guard must span both regimes.
	pools.set_custom_source("animals", PackedStringArray(["cat"]))
	pools.set_custom_source("adjectives", PackedStringArray(["sleepy"]))
	var keys: Dictionary = {}
	for i: int in range(3):   # 1 custom + 2 backfilled (4-combo space)
		var prompt: Prompt = pools.draw_prompt(type)
		assert_bool(keys.has(prompt.combo_key)).is_false()
		keys[prompt.combo_key] = true


func test_load_from_clears_custom_sources() -> void:
	var pools: PromptPools = _fixture_pools()
	pools.set_custom_source("animals", PackedStringArray(["heron"]))
	pools.load_from(FIXTURE_DIR)
	assert_bool(pools._custom_sources.is_empty()).is_true()
