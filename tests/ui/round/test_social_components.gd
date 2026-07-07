class_name TestSocialComponents
extends GdUnitTestSuite
## Slice 4 UI smoke tests (TDD §11): ReactionBar / KudosButton / KudosWallet
## instantiate and respond to EventBus syncs; the reveal grid grows a social
## row per cell that enables at JUDGING; the draw screen's retire path
## honors the self-save toggle. Multiplayer behavior is covered by the
## headless social suite + the automated round gate + owner playtests.

const REACTION_BAR: PackedScene = preload("res://ui/round/reaction_bar.tscn")
const KUDOS_BUTTON: PackedScene = preload("res://ui/round/kudos_button.tscn")
const KUDOS_WALLET: PackedScene = preload("res://ui/round/kudos_wallet.tscn")
const REVEAL: PackedScene = preload("res://ui/round/reveal_judging_screen.tscn")
const DRAW: PackedScene = preload("res://ui/round/draw_screen.tscn")
const SESSION_CLIENT_SCRIPT: GDScript = preload("res://game/session/session_client.gd")

const TEST_ROOT: String = "tests_tmp_collection_ui"


func before_test() -> void:
	CollectionStore.root_dir = TEST_ROOT
	_wipe_test_root()


func after_test() -> void:
	_wipe_test_root()
	CollectionStore.root_dir = "collection"


func _wipe_test_root() -> void:
	for file: String in Save.list_dir(TEST_ROOT + "/thumbs"):
		Save.delete(TEST_ROOT + "/thumbs/" + file)
	for file: String in Save.list_dir(TEST_ROOT):
		Save.delete(TEST_ROOT + "/" + file)


func _now_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)


func _instantiate(scene: PackedScene) -> Node:
	var node: Node = auto_free(scene.instantiate())
	add_child(node)
	return node


func _find_all_of(node: Node, type_check: Callable, found: Array) -> void:
	for child: Node in node.get_children():
		if bool(type_check.call(child)):
			found.append(child)
		_find_all_of(child, type_check, found)


func test_reaction_bar_six_buttons_interactive_and_counts() -> void:
	var bar: ReactionBar = _instantiate(REACTION_BAR)
	bar.drawing_id = "d1"
	var buttons: Array = []
	_find_all_of(bar, func(n: Node) -> bool: return n is Button, buttons)
	assert_int(buttons.size()).is_equal(6)
	for btn: Button in buttons:
		assert_bool(btn.disabled).is_true()   # gate closed by default
	bar.interactive = true
	for btn: Button in buttons:
		assert_bool(btn.disabled).is_false()
	# Host count sync updates the badge; other drawings' syncs are ignored.
	EventBus.reaction_counts_changed.emit("d1", {NetIds.Reaction.LAUGH: 3})
	EventBus.reaction_counts_changed.emit("other", {NetIds.Reaction.LAUGH: 9})
	assert_str((buttons[NetIds.Reaction.LAUGH] as Button).text).contains("3")
	assert_str((buttons[NetIds.Reaction.LAUGH] as Button).text).not_contains("9")


func test_kudos_button_pending_confirm_flow_no_optimistic_spend() -> void:
	var kudos: KudosButton = _instantiate(KUDOS_BUTTON)
	kudos.drawing_id = "d1"
	kudos.gate_open = true
	# No wallet in the test env (no session): idle but disabled.
	assert_bool(kudos.disabled).is_true()
	kudos.pressed.emit()   # simulate the press despite env wallet
	assert_str(kudos.text).contains("…")      # pending - nothing deducted
	EventBus.kudos_total_changed.emit("d1", 2)
	EventBus.kudos_given.emit("d1", 1)        # host confirm
	assert_str(kudos.text).contains("Given")
	assert_str(kudos.text).contains("×2")
	assert_bool(kudos.disabled).is_true()


func test_kudos_wallet_renders_pips_for_local_player() -> void:
	var wallet: KudosWallet = _instantiate(KUDOS_WALLET)
	assert_str(wallet.text).is_equal("")      # no session -> hidden
	# Register under whatever peer id Session.local_player() resolves in this
	# env (0 without an active transport; earlier net suites may change it).
	var me: Roster.PlayerState = Session.roster.register(
			Net.local_peer_id(), "test-uid", "Tester")
	me.kudos_granted = 3
	me.kudos_spent = 1
	EventBus.kudos_wallet_changed.emit(2)     # any wallet event triggers refresh
	assert_int(wallet.text.count("🏅")).is_equal(2)   # 2 remaining medals
	assert_int(wallet.text.length()).is_equal(3)      # + 1 spent pip
	Session.roster.remove_by_peer(Net.local_peer_id())


func test_reveal_cells_gain_social_row_that_enables_at_judging() -> void:
	var entries: Array = [
		{"drawing_id": "id-a", "doc": {"v": 1, "orientation": "landscape", "ops": []}},
		{"drawing_id": "id-b", "doc": {"v": 1, "orientation": "portrait", "ops": [{"t": "clear"}]}},
	]
	var client: SessionClient = auto_free(SESSION_CLIENT_SCRIPT.new())
	add_child(client)
	client.rpc_sync_phase(NetIds.Phase.REVEAL,
			{"entries": entries, "deadline_ms": _now_ms() + 5000})
	var screen: Control = _instantiate(REVEAL)
	screen.setup({"entries": entries, "deadline_ms": _now_ms() + 5000}, client)
	var bars: Array = []
	_find_all_of(screen, func(n: Node) -> bool: return n is ReactionBar, bars)
	var kudos_buttons: Array = []
	_find_all_of(screen, func(n: Node) -> bool: return n is KudosButton, kudos_buttons)
	assert_int(bars.size()).is_equal(2)
	assert_int(kudos_buttons.size()).is_equal(2)
	for bar: ReactionBar in bars:
		assert_bool(bar.interactive).is_false()   # REVEAL: gate closed
	screen.enter_judging({"deadline_ms": _now_ms() + 30_000})
	for bar: ReactionBar in bars:
		assert_bool(bar.interactive).is_true()    # JUDGING: reactions live
	for kb: KudosButton in kudos_buttons:
		assert_bool(kb.gate_open).is_true()


func test_sim_start_rebroadcasts_fresh_kudos_budgets() -> void:
	# Rematch staleness (owner, 2026-07-07): GameSession.start_game() resets
	# the kudos economy on the HOST roster only. Without a roster re-broadcast
	# right after, client wallets keep the PREVIOUS game's spent counts and
	# their kudos buttons wrongly disable.
	Session.roster.register(1, "uid-host", "Host")
	Session.roster.register(2, "uid-two", "Two")
	for p: Roster.PlayerState in Session.roster.players_in_join_order():
		p.kudos_granted = 1
		p.kudos_spent = 1   # wallet emptied in the "previous" game
	var synced: Array = []
	var handler: Callable = func(players: Array) -> void: synced.assign(players)
	EventBus.roster_updated.connect(handler)
	var client: SessionClient = auto_free(SESSION_CLIENT_SCRIPT.new())
	add_child(client)
	client._maybe_start_simulation(true)
	EventBus.roster_updated.disconnect(handler)
	assert_int(synced.size()).is_equal(2)
	for entry: Variant in synced:
		var d: Dictionary = entry
		assert_int(int(d["kudos_granted"])).is_greater(0)   # fresh allotment
		assert_int(int(d["kudos_spent"])).is_equal(0)       # fresh wallet
	Session.roster.remove_by_peer(1)
	Session.roster.remove_by_peer(2)


func test_draw_screen_self_save_on_retire_when_toggle_active() -> void:
	var client: SessionClient = auto_free(SESSION_CLIENT_SCRIPT.new())
	add_child(client)
	var screen: Control = DRAW.instantiate()
	add_child(screen)
	screen.setup({"prompt_text": "sleepy aardvark", "deadline_ms": _now_ms() + 30_000}, client)
	var canvas: DrawingCanvas = screen.find_child("Canvas", true, false)
	canvas.save_to_collection = true
	screen._send_current_doc()                 # player submitted once
	screen.queue_free()                        # phase swap retires the screen
	await get_tree().process_frame
	var index: Dictionary = Save.read_json(TEST_ROOT + "/index.json", {})
	var items: Array = index.get("items", [])
	assert_int(items.size()).is_equal(1)
	assert_str(str((items[0] as Dictionary)["source"])).is_equal("self")
	assert_str(str((items[0] as Dictionary)["prompt"])).is_equal("sleepy aardvark")


func test_draw_screen_no_save_when_toggle_off_or_never_submitted() -> void:
	var client: SessionClient = auto_free(SESSION_CLIENT_SCRIPT.new())
	add_child(client)
	# Toggle off, submitted: no save.
	var screen_a: Control = DRAW.instantiate()
	add_child(screen_a)
	screen_a.setup({"prompt_text": "p", "deadline_ms": _now_ms() + 30_000}, client)
	screen_a._send_current_doc()
	screen_a.queue_free()
	# Toggle on, never submitted: no save.
	var screen_b: Control = DRAW.instantiate()
	add_child(screen_b)
	screen_b.setup({"prompt_text": "p", "deadline_ms": _now_ms() + 30_000}, client)
	(screen_b.find_child("Canvas", true, false) as DrawingCanvas).save_to_collection = true
	screen_b.queue_free()
	await get_tree().process_frame
	var index: Dictionary = Save.read_json(TEST_ROOT + "/index.json", {})
	assert_int((index.get("items", []) as Array).size()).is_equal(0)
