class_name TestMusicRotation
extends GdUnitTestSuite
## Slice 21: host-side drawing-music rotation - shuffled bag over the
## enabled set, no repeats until exhausted, deterministic under a seed
## (TDD 21 §2).


func _make_session(mask: int, seed_value: int = 1234) -> GameSession:
	var roster := Roster.new()
	for i: int in range(3):
		roster.register(i + 1, "p%d" % i, "Player %d" % i)
	var settings := GameSettings.new()
	settings.drawing_tracks = mask
	var session := GameSession.new(settings, roster)
	session.rng.seed = seed_value
	return session


func test_bag_covers_enabled_set_before_repeating() -> void:
	var session: GameSession = _make_session(GameSettings.DRAWING_TRACKS_ALL)
	var expected: Array[String] = GameConstants.DRAWING_MUSIC_TRACKS.duplicate()
	expected.sort()
	for round_pair: int in 3:  # three consecutive bags, each must cover the set
		var pair: Array[String] = [session._next_music_track(), session._next_music_track()]
		pair.sort()
		assert_array(pair).is_equal(expected)


func test_single_track_mask_degenerates_to_that_track() -> void:
	var session: GameSession = _make_session(2)
	for i: int in 4:
		assert_str(session._next_music_track()).is_equal("m3-drawing-oompa")


func test_rotation_deterministic_under_seed() -> void:
	var a: GameSession = _make_session(GameSettings.DRAWING_TRACKS_ALL, 42)
	var b: GameSession = _make_session(GameSettings.DRAWING_TRACKS_ALL, 42)
	for i: int in 6:
		assert_str(a._next_music_track()).is_equal(b._next_music_track())


func test_hostile_empty_mask_falls_back_instead_of_hanging() -> void:
	# clamp_to_limits normally prevents mask 0; the bag guards anyway.
	var session: GameSession = _make_session(0)
	assert_str(session._next_music_track()).is_equal(GameConstants.DRAWING_MUSIC_TRACKS[0])
