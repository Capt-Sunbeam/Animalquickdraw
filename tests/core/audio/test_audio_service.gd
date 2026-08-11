class_name TestAudioService
extends GdUnitTestSuite
## Slice 21: AudioService state machine - music decisions, cue arming,
## volume prefs. Asserts STATE (current_music / is_cue_armed / persisted
## dict), never audible output (headless CI has no audio device). Handlers
## are called directly instead of emitting EventBus signals so no other
## autoload reacts (Audio state is the unit under test).

const SCRATCH_PROFILE: String = "test_audio_profile.json"


func before_test() -> void:
	Audio.profile_path = SCRATCH_PROFILE
	_reset_audio_state()


func after_test() -> void:
	Save.delete(SCRATCH_PROFILE)
	Audio.profile_path = "profile.json"
	Audio.set_volume(&"master", 1.0)
	Audio.set_volume(&"music", 1.0)
	Audio.set_volume(&"sfx", 1.0)
	_reset_audio_state()


func _reset_audio_state() -> void:
	Audio._on_session_closed("test")
	Audio._on_scene_changed(Routes.MENU)


func _deadline(secs_from_now: float) -> Dictionary:
	return {"deadline_ms": Audio._now_ms() + int(secs_from_now * 1000.0)}


func test_every_drawing_track_has_a_stream() -> void:
	for track: String in GameConstants.DRAWING_MUSIC_TRACKS:
		assert_bool(Audio.MUSIC.has(StringName(track))).is_true()


func test_menu_family_plays_m1() -> void:
	for route: String in [Routes.MENU, Routes.COLLECTION, Routes.AVATAR_EDITOR,
			Routes.PUBLIC_BROWSER, Routes.CANVAS_SANDBOX]:
		Audio._on_scene_changed(route)
		assert_str(String(Audio.current_music())).is_equal("m1-main-menu")


func test_lobby_and_pool_setup_play_m2() -> void:
	Audio._on_scene_changed(Routes.LOBBY)
	assert_str(String(Audio.current_music())).is_equal("m2-lobby")
	Audio._on_scene_changed(Routes.ROUND)
	Audio._on_phase_changed(NetIds.Phase.POOL_SETUP, {})
	assert_str(String(Audio.current_music())).is_equal("m2-lobby")


func test_drawing_plays_the_intro_payload_track() -> void:
	Audio._on_scene_changed(Routes.ROUND)
	Audio._on_phase_changed(NetIds.Phase.ROUND_INTRO,
			_deadline(4.0).merged({"music_track": "m3-drawing-oompa"}))
	assert_str(String(Audio.current_music())).is_equal("")  # stingers own the intro
	Audio._on_phase_changed(NetIds.Phase.DRAWING, _deadline(30.0))
	assert_str(String(Audio.current_music())).is_equal("m3-drawing-oompa")


func test_empty_track_id_means_silent_drawing() -> void:
	# Owner polish B1 (2026-08-10): "" in the payload = host chose no tracks.
	Audio._on_scene_changed(Routes.ROUND)
	Audio._on_phase_changed(NetIds.Phase.ROUND_INTRO,
			_deadline(4.0).merged({"music_track": ""}))
	Audio._on_phase_changed(NetIds.Phase.DRAWING, _deadline(30.0))
	assert_str(String(Audio.current_music())).is_equal("")


func test_unknown_track_id_falls_back_to_ambient() -> void:
	Audio._on_scene_changed(Routes.ROUND)
	Audio._on_phase_changed(NetIds.Phase.ROUND_INTRO,
			_deadline(4.0).merged({"music_track": "m9-hostile"}))
	Audio._on_phase_changed(NetIds.Phase.DRAWING, _deadline(30.0))
	assert_str(String(Audio.current_music())).is_equal("m3-drawing-ambient")


func test_reveal_resolution_wrap_up_and_paused_are_silent() -> void:
	# JUDGING left this set 2026-08-10 (M6 - polish A2); REVEAL stays silent
	# (the per-canvas snippet is SFX, not music).
	Audio._on_scene_changed(Routes.ROUND)
	for phase: int in [NetIds.Phase.REVEAL,
			NetIds.Phase.RESOLUTION, NetIds.Phase.WRAP_UP, NetIds.Phase.PAUSED]:
		Audio._on_phase_changed(phase, {})
		assert_str(String(Audio.current_music())).is_equal("")


func test_judging_plays_m6() -> void:
	Audio._on_scene_changed(Routes.ROUND)
	Audio._on_phase_changed(NetIds.Phase.JUDGING, _deadline(25.0))
	assert_str(String(Audio.current_music())).is_equal("m6-judging")
	Audio._on_phase_changed(NetIds.Phase.RESOLUTION, {})
	assert_str(String(Audio.current_music())).is_equal("")


func test_music_db_offsets_only_name_known_tracks() -> void:
	for id: StringName in Audio.MUSIC_DB_OFFSET.keys():
		assert_bool(Audio.MUSIC.has(id)).is_true()


func test_paused_fades_drawing_music_out_and_resume_restores() -> void:
	# Owner D2: pause = fade to silence; the resume re-broadcast of DRAWING
	# (fresh deadline) brings the track back.
	Audio._on_scene_changed(Routes.ROUND)
	Audio._on_phase_changed(NetIds.Phase.DRAWING, _deadline(30.0))
	assert_str(String(Audio.current_music())).is_equal("m3-drawing-ambient")
	Audio._on_phase_changed(NetIds.Phase.PAUSED, {})
	assert_str(String(Audio.current_music())).is_equal("")
	Audio._on_phase_changed(NetIds.Phase.DRAWING, _deadline(20.0))
	assert_str(String(Audio.current_music())).is_equal("m3-drawing-ambient")


func test_cue_arms_on_timed_phases_and_disarms_elsewhere() -> void:
	Audio._on_scene_changed(Routes.ROUND)
	Audio._on_phase_changed(NetIds.Phase.DRAWING, _deadline(30.0))
	assert_bool(Audio.is_cue_armed()).is_true()
	Audio._on_phase_changed(NetIds.Phase.REVEAL, {})
	assert_bool(Audio.is_cue_armed()).is_false()
	Audio._on_phase_changed(NetIds.Phase.JUDGING, _deadline(25.0))
	assert_bool(Audio.is_cue_armed()).is_true()
	Audio._on_phase_changed(NetIds.Phase.PAUSED, {})
	assert_bool(Audio.is_cue_armed()).is_false()


func test_cue_missing_deadline_never_arms() -> void:
	Audio._on_scene_changed(Routes.ROUND)
	Audio._on_phase_changed(NetIds.Phase.DRAWING, {})
	assert_bool(Audio.is_cue_armed()).is_false()


func test_leaving_round_resets_to_menu_music() -> void:
	Audio._on_scene_changed(Routes.ROUND)
	Audio._on_phase_changed(NetIds.Phase.DRAWING, _deadline(30.0))
	Audio._on_session_closed("host_quit")
	Audio._on_scene_changed(Routes.MENU)
	assert_str(String(Audio.current_music())).is_equal("m1-main-menu")
	assert_bool(Audio.is_cue_armed()).is_false()


func test_volume_set_clamps_and_persists_via_seam() -> void:
	Audio.set_volume(&"music", 0.3)
	Audio.set_volume(&"sfx", 1.5)   # clamps to 1.0
	Audio.save_volumes()
	assert_float(Audio.get_volume(&"music")).is_equal_approx(0.3, 0.001)
	assert_float(Audio.get_volume(&"sfx")).is_equal_approx(1.0, 0.001)
	var profile: Dictionary = Save.read_json(SCRATCH_PROFILE, {})
	var audio: Dictionary = profile.get("audio", {})
	assert_float(float(audio.get("music", -1.0))).is_equal_approx(0.3, 0.001)
	assert_float(float(audio.get("sfx", -1.0))).is_equal_approx(1.0, 0.001)
