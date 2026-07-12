class_name TestSteamBackendLogic
extends GdUnitTestSuite
## Slice 12: SteamBackend pure logic + backend selection (TDD 12 §11).
## Construction-only - no Steam init happens in tests; Steam-touching paths
## are covered by the manual two-account protocol (TDD 12 §7).

const PlatformServiceScript := preload("res://core/platform/platform_service.gd")


func test_steam_backend_constructs_without_init() -> void:
	var backend := SteamBackend.new()
	assert_bool(backend is PlatformBackend).is_true()
	# Pre-init: everything Steam-dependent reports unavailable, never crashes.
	assert_bool(backend.supports_invites()).is_false()
	assert_bool(backend.is_stats_ready()).is_false()
	assert_str(backend.get_room_code()).is_equal("")
	assert_str(backend.get_last_failure_reason()).is_equal("")


func test_editor_runs_default_to_enet() -> void:
	# Headless test runs use the editor binary, so the dev default applies -
	# this pins "tests and dev_run.sh never accidentally pick Steam".
	assert_str(PlatformServiceScript.default_platform_kind()).is_equal("enet")


func test_friendly_join_failure_maps_known_responses() -> void:
	assert_str(SteamBackend.friendly_join_failure(
			Steam.CHAT_ROOM_ENTER_RESPONSE_FULL)).is_equal("full")
	assert_str(SteamBackend.friendly_join_failure(
			Steam.CHAT_ROOM_ENTER_RESPONSE_DOESNT_EXIST)).is_equal("not_found")
	assert_str(SteamBackend.friendly_join_failure(
			Steam.CHAT_ROOM_ENTER_RESPONSE_BANNED)).is_equal("connection_failed")
	assert_str(SteamBackend.friendly_join_failure(-1)).is_equal("connection_failed")


func test_choose_lobby_picks_highest_member_count() -> void:
	var picked: int = SteamBackend.choose_lobby([
		{"id": 100, "players": 2},
		{"id": 200, "players": 5},
		{"id": 300, "players": 3},
	])
	assert_int(picked).is_equal(200)


func test_choose_lobby_tie_keeps_steam_result_order() -> void:
	var picked: int = SteamBackend.choose_lobby([
		{"id": 100, "players": 4},
		{"id": 200, "players": 4},
	])
	assert_int(picked).is_equal(100)


func test_choose_lobby_empty_returns_zero() -> void:
	assert_int(SteamBackend.choose_lobby([])).is_equal(0)
