class_name TestPublicBrowser
extends GdUnitTestSuite
## Slice 13: LobbyListing strict parse, PublicNoticeGate persistence, and
## public-browser screen behavior over a stubbed backend (TDD 13 §11).
## The gate tests write to a SCRATCH profile file via the path seam - the
## owner's real profile.json is never touched (session-8 pollution lesson).

const BROWSER_SCREEN: PackedScene = preload("res://ui/lobby/public_browser_screen.tscn")
const NOTICE_DIALOG: PackedScene = preload("res://ui/lobby/public_notice_dialog.tscn")
const MAIN_MENU: PackedScene = preload("res://ui/menu/main_menu_screen.tscn")

const SCRATCH_PROFILE: String = "test_public_notice_profile.json"


class BrowserStubBackend:
	extends PlatformBackend
	var canned: Dictionary = {"ok": true, "lobbies": []}

	func supports_lobby_browser() -> bool:
		return true

	func request_lobby_list() -> Dictionary:
		return canned


func before_test() -> void:
	TextFilter.configure(PackedStringArray(["badword"]))
	PublicNoticeGate.path = SCRATCH_PROFILE
	Save.delete(SCRATCH_PROFILE)


func after_test() -> void:
	TextFilter.configure(PackedStringArray())
	Save.delete(SCRATCH_PROFILE)
	PublicNoticeGate.path = "profile.json"


func _valid_meta(players: int = 3, ingame: bool = false) -> Dictionary:
	var s: GameSettings = GameSettings.new()
	s.set_value(&"is_public", true)
	return LobbyMetadata.build_full("ABCDE", "Alice", s.to_dict(), players, ingame)


# --- LobbyListing strict parse ---


func test_listing_parses_valid_metadata() -> void:
	var s: GameSettings = GameSettings.new()
	s.set_value(&"is_public", true)
	var meta: Dictionary = LobbyMetadata.build_full("ABCDE", "Alice", s.to_dict(), 3, false)
	var listing: LobbyListing = LobbyListing.from_lobby_metadata(42, meta)
	assert_object(listing).is_not_null()
	assert_int(listing.lobby_id).is_equal(42)
	assert_str(listing.name).is_equal("Alice's game")
	assert_str(listing.mode).is_equal("default")
	assert_int(listing.players_cur).is_equal(3)
	assert_int(listing.players_max).is_equal(GameConstants.MAX_PLAYERS)
	assert_int(listing.rounds).is_equal(int(s.to_dict()["round_count"]))
	assert_int(listing.draw_time).is_equal(int(s.to_dict()["draw_time_sec"]))
	assert_str(listing.pool_type).is_equal("builtin")
	assert_bool(listing.has_space()).is_true()


func test_listing_drops_missing_or_malformed_metadata() -> void:
	assert_object(LobbyListing.from_lobby_metadata(42, {})).is_null()
	assert_object(LobbyListing.from_lobby_metadata(0, _valid_meta())).is_null()
	var bad_mode: Dictionary = _valid_meta()
	bad_mode[LobbyMetadata.KEY_MODE] = "hax"
	assert_object(LobbyListing.from_lobby_metadata(42, bad_mode)).is_null()
	var bad_players: Dictionary = _valid_meta()
	bad_players[LobbyMetadata.KEY_PLAYERS] = "0"
	assert_object(LobbyListing.from_lobby_metadata(42, bad_players)).is_null()
	var forged_players: Dictionary = _valid_meta()
	forged_players[LobbyMetadata.KEY_PLAYERS] = "99"
	assert_object(LobbyListing.from_lobby_metadata(42, forged_players)).is_null()
	var blank_name: Dictionary = _valid_meta()
	blank_name[LobbyMetadata.KEY_NAME] = "   "
	assert_object(LobbyListing.from_lobby_metadata(42, blank_name)).is_null()


func test_listing_drops_version_mismatch() -> void:
	var meta: Dictionary = _valid_meta()
	meta[LobbyMetadata.KEY_PROTO] = "not-our-proto"
	assert_object(LobbyListing.from_lobby_metadata(42, meta)).is_null()


func test_listing_drops_private_and_ingame_lobbies() -> void:
	# Steam-side filters should exclude these; the strict parse is the
	# defense against stale results and forged flags (TDD 13 §10).
	var s: GameSettings = GameSettings.new()   # is_public stays false
	var private_meta: Dictionary = LobbyMetadata.build_full(
			"ABCDE", "Alice", s.to_dict(), 3, false)
	assert_object(LobbyListing.from_lobby_metadata(42, private_meta)).is_null()
	assert_object(LobbyListing.from_lobby_metadata(42, _valid_meta(3, true))).is_null()


func test_listing_recensors_name_with_local_blocklist() -> void:
	# A modified host can write uncensored metadata; the browser censors
	# again locally before any rendering (defense in depth).
	var meta: Dictionary = _valid_meta()
	meta[LobbyMetadata.KEY_NAME] = "badword's game"
	var listing: LobbyListing = LobbyListing.from_lobby_metadata(42, meta)
	assert_object(listing).is_not_null()
	assert_str(listing.name).is_equal("***'s game")


# --- PublicNoticeGate ---


func test_notice_gate_unaccepted_by_default_and_persists_acceptance() -> void:
	assert_bool(PublicNoticeGate.is_accepted()).is_false()
	PublicNoticeGate.mark_accepted()
	assert_bool(PublicNoticeGate.is_accepted()).is_true()
	# Second read (fresh from disk) still holds - accept-once-per-install.
	assert_bool(PublicNoticeGate.is_accepted()).is_true()


func test_notice_gate_reprompts_on_version_bump() -> void:
	# Acceptance of an OLDER wording version does not satisfy the current
	# one (Slice 15 bumps PUBLIC_NOTICE_VERSION after the legal pass).
	Save.write_json(SCRATCH_PROFILE,
			{"public_notice_accepted_v": GameConstants.PUBLIC_NOTICE_VERSION - 1})
	assert_bool(PublicNoticeGate.is_accepted()).is_false()


func test_notice_dialog_accept_persists_decline_does_not() -> void:
	var dialog: PublicNoticeDialog = auto_free(NOTICE_DIALOG.instantiate())
	add_child(dialog)
	assert_str(dialog.dialog_text).is_equal(GameConstants.PUBLIC_NOTICE_TEXT)
	dialog.canceled.emit()
	assert_bool(PublicNoticeGate.is_accepted()).is_false()
	dialog.confirmed.emit()
	assert_bool(PublicNoticeGate.is_accepted()).is_true()


# --- Browser screen over a stubbed backend ---


func _instantiate_browser(stub: BrowserStubBackend) -> Control:
	var original: PlatformBackend = Platform.backend
	Platform.backend = stub
	var screen: Control = auto_free(BROWSER_SCREEN.instantiate())
	add_child(screen)
	Platform.backend = original
	return screen


func _live_row_count(screen: Control) -> int:
	var rows: VBoxContainer = screen.find_child("Rows", true, false)
	var count: int = 0
	for child: Node in rows.get_children():
		if not child.is_queued_for_deletion():
			count += 1
	return count


func test_browser_renders_rows_and_empty_state() -> void:
	var stub := BrowserStubBackend.new()
	stub.canned = {"ok": true, "lobbies": [
		{"id": 1, "meta": _valid_meta(3)},
		{"id": 2, "meta": _valid_meta(GameConstants.MAX_PLAYERS)},
		{"id": 3, "meta": {}},   # malformed - dropped, never rendered
	]}
	var screen: Control = _instantiate_browser(stub)
	assert_int(_live_row_count(screen)).is_equal(2)
	# Full lobby keeps its row (information); only Join is disabled (§7).
	var rows: VBoxContainer = screen.find_child("Rows", true, false)
	var full_join: Button = rows.get_child(1).get_child(-1)
	assert_bool(full_join.disabled).is_true()
	var open_join: Button = rows.get_child(0).get_child(-1)
	assert_bool(open_join.disabled).is_false()

	var empty := BrowserStubBackend.new()
	var empty_screen: Control = _instantiate_browser(empty)
	assert_int(_live_row_count(empty_screen)).is_equal(0)
	var status: Label = empty_screen.find_child("StatusLabel", true, false)
	assert_str(status.text).contains("No open public games")


func test_browser_failed_state_shows_retry() -> void:
	var stub := BrowserStubBackend.new()
	stub.canned = {"ok": false, "lobbies": []}
	var screen: Control = _instantiate_browser(stub)
	var retry: Button = screen.find_child("RetryButton", true, false)
	assert_bool(retry.visible).is_true()
	var status: Label = screen.find_child("StatusLabel", true, false)
	assert_str(status.text).contains("try again")


func test_browser_has_space_filter_hides_full_lobbies() -> void:
	var stub := BrowserStubBackend.new()
	stub.canned = {"ok": true, "lobbies": [
		{"id": 1, "meta": _valid_meta(3)},
		{"id": 2, "meta": _valid_meta(GameConstants.MAX_PLAYERS)},
	]}
	var screen: Control = _instantiate_browser(stub)
	assert_int(_live_row_count(screen)).is_equal(2)
	var space_check: CheckBox = screen.find_child("SpaceCheck", true, false)
	space_check.button_pressed = true   # emits toggled -> refilter
	await get_tree().process_frame
	assert_int(_live_row_count(screen)).is_equal(1)


func test_browser_mode_filter_refilters_locally() -> void:
	var social: Dictionary = _valid_meta(3)
	social[LobbyMetadata.KEY_MODE] = "social"
	var stub := BrowserStubBackend.new()
	stub.canned = {"ok": true, "lobbies": [
		{"id": 1, "meta": _valid_meta(4)},
		{"id": 2, "meta": social},
	]}
	var screen: Control = _instantiate_browser(stub)
	assert_int(_live_row_count(screen)).is_equal(2)
	var mode_option: OptionButton = screen.find_child("ModeOption", true, false)
	var social_index: int = -1
	for i: int in range(mode_option.item_count):
		if str(mode_option.get_item_metadata(i)) == "social":
			social_index = i
	mode_option.select(social_index)
	mode_option.item_selected.emit(social_index)
	await get_tree().process_frame
	assert_int(_live_row_count(screen)).is_equal(1)


func test_browser_join_gates_on_unaccepted_notice() -> void:
	var stub := BrowserStubBackend.new()
	stub.canned = {"ok": true, "lobbies": [{"id": 1, "meta": _valid_meta(3)}]}
	var screen: Control = _instantiate_browser(stub)
	var rows: VBoxContainer = screen.find_child("Rows", true, false)
	var join: Button = rows.get_child(0).get_child(-1)
	join.pressed.emit()
	var dialog: PublicNoticeDialog = screen.find_child("NoticeDialog", true, false)
	assert_bool(dialog.visible).is_true()
	# Declining persists nothing and returns to the list (§5).
	dialog.canceled.emit()
	assert_bool(PublicNoticeGate.is_accepted()).is_false()


func test_menu_public_button_disabled_on_enet_with_tooltip() -> void:
	# Test env runs the ENet backend: surface present, action gated (§10).
	var menu: Control = auto_free(MAIN_MENU.instantiate())
	add_child(menu)
	var public_button: Button = menu.find_child("PublicButton", true, false)
	assert_object(public_button).is_not_null()
	assert_bool(public_button.disabled).is_true()
	assert_str(public_button.tooltip_text).contains("Steam")
