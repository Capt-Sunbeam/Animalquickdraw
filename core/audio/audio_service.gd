extends Node
## Autoload "Audio" (Slice 21) - all game audio: music state machine, SFX pool,
## timer cue, volume prefs. Never networked: global sounds hook EventBus
## signals the host already broadcasts to every peer; local sounds hook
## local-only signals or direct play_sfx calls from UI. Music is event-synced,
## not sample-synced. See TDD/21-audio-wiring.md.

const MUSIC: Dictionary = {
	&"m1-main-menu": preload("res://assets/audio/m1-main-menu.ogg"),
	&"m2-lobby": preload("res://assets/audio/m2-lobby.ogg"),
	&"m3-drawing-ambient": preload("res://assets/audio/m3-drawing-ambient.ogg"),
	&"m3-drawing-oompa": preload("res://assets/audio/m3-drawing-oompa.ogg"),
	&"m6-judging": preload("res://assets/audio/m6-judging.ogg"),
}

## Per-track mix trim in dB, applied as the incoming fade target (0 = full
## Music-bus level). Owner tuning knob - M6 may want to sit lower than the
## other music (2026-08-10); adjust by ear in playtests, no re-render needed.
const MUSIC_DB_OFFSET: Dictionary = {
	&"m6-judging": 0.0,
}

const SFX: Dictionary = {
	&"cue-timer-warning": preload("res://assets/audio/cue-timer-warning.wav"),
	&"s1-race-start": preload("res://assets/audio/s1-race-start.wav"),
	&"s2-prompt-reveal": preload("res://assets/audio/s2-prompt-reveal.wav"),
	&"s4-winner": preload("res://assets/audio/s4-winner.wav"),
	&"s6-title-awarded": preload("res://assets/audio/s6-title-awarded.wav"),
	&"s7-final-podium": preload("res://assets/audio/s7-final-podium.wav"),
	&"sfx-all-ready": preload("res://assets/audio/sfx-all-ready.wav"),
	&"sfx-button-press": preload("res://assets/audio/sfx-button-press.wav"),
	&"sfx-chat-pop": preload("res://assets/audio/sfx-chat-pop.wav"),
	&"sfx-eraser": preload("res://assets/audio/sfx-eraser.wav"),
	&"sfx-judge-latch": preload("res://assets/audio/sfx-judge-latch.wav"),
	&"sfx-kudos": preload("res://assets/audio/sfx-kudos.wav"),
	&"sfx-pause": preload("res://assets/audio/sfx-pause.wav"),
	&"sfx-player-join": preload("res://assets/audio/sfx-player-join.wav"),
	&"sfx-player-leave": preload("res://assets/audio/sfx-player-leave.wav"),
	&"sfx-ready-click": preload("res://assets/audio/sfx-ready-click.wav"),
	&"sfx-reveal": preload("res://assets/audio/sfx-reveal.wav"),
	&"sfx-text-stamp": preload("res://assets/audio/sfx-text-stamp.wav"),
	&"sfx-toggle-off": preload("res://assets/audio/sfx-toggle-off.wav"),
	&"sfx-toggle-on": preload("res://assets/audio/sfx-toggle-on.wav"),
	&"sfx-undo-poof": preload("res://assets/audio/sfx-undo-poof.wav"),
	&"sfx-unpause": preload("res://assets/audio/sfx-unpause.wav"),
}

## The canonical drawing-track list (bit order) lives in
## GameConstants.DRAWING_MUSIC_TRACKS - the sim picks from it, we validate
## against it. A test pins that MUSIC carries a stream for every entry.
const FALLBACK_DRAWING_TRACK: StringName = &"m3-drawing-ambient"

const MUSIC_FADE_SEC: float = 0.5
const CUE_MUSIC_FADE_SEC: float = 1.0
## Measured landing-note onset in cue-timer-warning.wav (v2, 2026-08-10): the
## A4 beep IS the landing (owner: it must end the timer precisely) - the cue
## starts so its onset lands on the phase-change deadline (T-4.046 s); four F4
## beeps count down before it, trailing file silence rings past the change.
const CUE_LANDING_SEC: float = 4.046
## Measured BEEP onset in s1-race-start.wav: S1 starts so the BEEP lands on the
## ROUND_INTRO deadline = the drawing-start frame.
const S1_BEEP_SEC: float = 2.84
## A landing sound is left to ring out at phase change if the phase ended within
## this window of its deadline (natural expiry); an earlier exit cuts it.
const LANDING_GRACE_MS: int = 500
const SILENT_DB: float = -60.0
const SFX_POOL_SIZE: int = 8
const CHAT_POP_JITTER: float = 0.05

## Test seam (PublicNoticeGate.path pattern) - tests point this at a scratch
## file so volume writes never touch the owner's real profile.json.
var profile_path: String = "profile.json"

var _volumes: Dictionary = {&"master": 1.0, &"music": 1.0, &"sfx": 1.0}
var _music_players: Array[AudioStreamPlayer] = []
var _music_active: int = 0
var _music_id: StringName = &""
var _music_tweens: Array[Tween] = [null, null]
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_next: int = 0
var _cue_player: AudioStreamPlayer

var _route: String = Routes.MENU
var _phase: int = -1  # NetIds.Phase; -1 = not in a game
var _drawing_track: StringName = FALLBACK_DRAWING_TRACK
var _cue_deadline_ms: int = 0  # 0 = disarmed
var _cue_played: bool = false
var _s1_deadline_ms: int = 0
var _s1_played: bool = false
var _lobby_roster_count: int = -1  # -1 = no baseline yet


func _ready() -> void:
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = &"Music"
		add_child(p)
		_music_players.append(p)
	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_sfx_pool.append(p)
	_cue_player = AudioStreamPlayer.new()
	_cue_player.bus = &"SFX"
	add_child(_cue_player)
	_load_volumes()

	EventBus.scene_changed.connect(_on_scene_changed)
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.session_closed.connect(_on_session_closed)
	EventBus.game_paused.connect(_on_game_paused)
	EventBus.game_resumed.connect(_on_game_resumed)
	EventBus.chat_message_received.connect(_on_chat_message)
	EventBus.kudos_total_changed.connect(_on_kudos_total_changed)
	EventBus.roster_updated.connect(_on_roster_updated)
	EventBus.player_late_joined.connect(_on_player_gained)
	EventBus.player_rejoined.connect(_on_player_gained)
	EventBus.player_dropped.connect(_on_player_lost)
	EventBus.player_kicked.connect(_on_player_lost)
	EventBus.round_resolved.connect(_on_round_resolved)
	EventBus.judge_pick_latched.connect(_on_judge_pick_latched)
	EventBus.reveal_beat_started.connect(_on_reveal_beat_started)
	get_tree().node_added.connect(_on_node_added)
	_update_music()


func _process(_delta: float) -> void:
	if _cue_deadline_ms > 0 and not _cue_played:
		var remaining_ms := _cue_deadline_ms - _now_ms()
		if remaining_ms <= int(CUE_LANDING_SEC * 1000.0):
			_cue_played = true
			_cue_player.stream = SFX[&"cue-timer-warning"]
			_cue_player.play(maxf(0.0, CUE_LANDING_SEC - remaining_ms / 1000.0))
			# Owner requirement: music fades smoothly INTO the cue - drawing
			# tracks and (since M6, 2026-08-10) the judging music alike.
			if (_phase == NetIds.Phase.DRAWING or _phase == NetIds.Phase.JUDGING) \
					and _music_id != &"":
				_crossfade_to(&"", CUE_MUSIC_FADE_SEC)
	if _s1_deadline_ms > 0 and not _s1_played:
		var remaining_ms := _s1_deadline_ms - _now_ms()
		if remaining_ms <= int(S1_BEEP_SEC * 1000.0):
			_s1_played = true
			play_sfx(&"s1-race-start", 1.0, maxf(0.0, S1_BEEP_SEC - remaining_ms / 1000.0))


## Fire a one-shot on the SFX bus. UI calls this directly for screen-local
## moments (title cards, canvas tools); AudioService's own handlers use it too.
func play_sfx(id: StringName, pitch_scale: float = 1.0, from_position: float = 0.0) -> void:
	if not SFX.has(id):
		push_error("Audio.play_sfx: unknown sfx id '%s'" % id)
		return
	var p := _sfx_pool[_sfx_next]
	_sfx_next = (_sfx_next + 1) % SFX_POOL_SIZE
	p.stream = SFX[id]
	p.pitch_scale = pitch_scale
	p.play(from_position)


## Current music id (&"" = silent). Test hook; also handy for debugging.
func current_music() -> StringName:
	return _music_id


## Slice 20 replays show undos as poofs on every peer - hosts of a
## ReplayPlayer attach this once and every UndoOp beat plays the poof.
func attach_replay_poof(player: ReplayPlayer, doc: DrawingDoc) -> void:
	player.op_started.connect(func(op_index: int) -> void:
		if op_index >= 0 and op_index < doc.ops.size() and doc.ops[op_index] is UndoOp:
			play_sfx(&"sfx-undo-poof"))


func is_cue_armed() -> bool:
	return _cue_deadline_ms > 0 and not _cue_played


## kind: &"master" | &"music" | &"sfx". linear 0..1; applied immediately.
## Call save_volumes() to persist (sliders apply on drag, save on release).
func set_volume(kind: StringName, linear: float) -> void:
	linear = clampf(linear, 0.0, 1.0)
	_volumes[kind] = linear
	_apply_volume(kind)


func get_volume(kind: StringName) -> float:
	return float(_volumes.get(kind, 1.0))


func save_volumes() -> void:
	var profile: Dictionary = Save.read_json(profile_path, {})
	profile["audio"] = {
		"master": _volumes[&"master"],
		"music": _volumes[&"music"],
		"sfx": _volumes[&"sfx"],
	}
	Save.write_json(profile_path, profile)


func _load_volumes() -> void:
	var profile: Dictionary = Save.read_json(profile_path, {})
	var audio: Dictionary = profile.get("audio", {})
	for kind: StringName in _volumes.keys():
		_volumes[kind] = clampf(float(audio.get(String(kind), 1.0)), 0.0, 1.0)
		_apply_volume(kind)


func _apply_volume(kind: StringName) -> void:
	const BUS_NAMES: Dictionary = {&"master": &"Master", &"music": &"Music", &"sfx": &"SFX"}
	var idx := AudioServer.get_bus_index(BUS_NAMES[kind])
	if idx < 0:
		return
	var linear: float = _volumes[kind]
	AudioServer.set_bus_mute(idx, linear <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))


## The one decision function: what should be playing right now.
## Pure on (_route, _phase, _drawing_track) - table-tested.
func _desired_music() -> StringName:
	if _route == Routes.ROUND:
		match _phase:
			NetIds.Phase.POOL_SETUP:
				return &"m2-lobby"
			NetIds.Phase.DRAWING:
				return _drawing_track
			NetIds.Phase.JUDGING:
				# M6 (2026-08-10 polish): the M4 cut's revisit condition fired.
				return &"m6-judging"
			_:
				# ROUND_INTRO (stingers own it), REVEAL/RESOLUTION/WRAP_UP
				# (silence + stingers; M4/M5 cut, M6 covers judging only),
				# PAUSED (owner D2: fade to silence), pre-phase limbo.
				return &""
	if _route == Routes.LOBBY:
		return &"m2-lobby"
	return &"m1-main-menu"  # menu family: menu, collection, avatars, browser, sandbox


func _update_music() -> void:
	var target := _desired_music()
	if target != _music_id:
		_crossfade_to(target, MUSIC_FADE_SEC)


func _crossfade_to(id: StringName, fade_sec: float) -> void:
	_music_id = id
	var outgoing := _music_players[_music_active]
	if outgoing.playing:
		_fade(_music_active, SILENT_DB, fade_sec, true)
	if id == &"":
		return
	_music_active = (_music_active + 1) % 2
	var incoming := _music_players[_music_active]
	incoming.stream = MUSIC[id]
	incoming.volume_db = SILENT_DB
	incoming.play()
	_fade(_music_active, float(MUSIC_DB_OFFSET.get(id, 0.0)), fade_sec, false)


func _fade(player_idx: int, to_db: float, sec: float, stop_after: bool) -> void:
	var tween := _music_tweens[player_idx]
	if tween != null and tween.is_valid():
		tween.kill()
	var player := _music_players[player_idx]
	tween = create_tween()
	tween.tween_property(player, "volume_db", to_db, sec)
	if stop_after:
		tween.tween_callback(player.stop)
	_music_tweens[player_idx] = tween


func _arm_cue(data: Dictionary) -> void:
	_cue_deadline_ms = int(data.get("deadline_ms", 0))
	_cue_played = false


func _disarm_cue(cut_if_early: bool) -> void:
	if cut_if_early and _cue_player.playing:
		# Natural expiry leaves the landing note ringing; an early exit
		# (all-ready advance, pause) cuts the now-wrong countdown.
		if _cue_deadline_ms - _now_ms() > LANDING_GRACE_MS:
			_cue_player.stop()
	_cue_deadline_ms = 0
	_cue_played = false


static func _now_ms() -> int:
	# Same clock as PhaseTimer: host deadlines are absolute unix-epoch ms.
	return int(Time.get_unix_time_from_system() * 1000.0)


func _on_scene_changed(route: String) -> void:
	_route = route
	if route != Routes.ROUND:
		_phase = -1
		_disarm_cue(true)
		_s1_deadline_ms = 0
	_update_music()


func _on_phase_changed(phase: NetIds.Phase, data: Dictionary) -> void:
	# All-ready chime: a timed phase only ends EARLY (deadline still far off)
	# via the Slice 17 all-ready advance, and only along these transitions -
	# no roster/judge bookkeeping needed. PAUSED is excluded by the pairing.
	if _cue_deadline_ms > 0 and _cue_deadline_ms - _now_ms() > LANDING_GRACE_MS:
		if (_phase == NetIds.Phase.DRAWING and phase == NetIds.Phase.REVEAL) \
				or (_phase == NetIds.Phase.JUDGING and phase == NetIds.Phase.RESOLUTION):
			play_sfx(&"sfx-all-ready")
	var entering_timed := phase == NetIds.Phase.DRAWING or phase == NetIds.Phase.JUDGING
	if entering_timed:
		_arm_cue(data)
	else:
		_disarm_cue(true)
	if phase != NetIds.Phase.ROUND_INTRO:
		_s1_deadline_ms = 0
	_phase = phase
	match phase:
		NetIds.Phase.REVEAL:
			# GRID style has no beats - the whole grid pops in with the phase,
			# so the reveal snippet fires once here (owner call, 2026-08-10).
			# ONE_AT_A_TIME plays it per beat via reveal_beat_started instead.
			if int(data.get("reveal_style", -1)) == GameSettings.RevealStyle.GRID:
				play_sfx(&"sfx-reveal")
		NetIds.Phase.ROUND_INTRO:
			var track := str(data.get("music_track", ""))
			# Tolerant-payload rule: unknown/missing id falls back (late
			# joiners mid-round never saw this payload at all).
			_drawing_track = StringName(track) if GameConstants.DRAWING_MUSIC_TRACKS.has(track) \
					else FALLBACK_DRAWING_TRACK
			play_sfx(&"s2-prompt-reveal")
			_s1_deadline_ms = int(data.get("deadline_ms", 0))
			_s1_played = false
	_update_music()


func _on_session_closed(_reason: String) -> void:
	_phase = -1
	_lobby_roster_count = -1
	_disarm_cue(true)
	_s1_deadline_ms = 0
	_update_music()


func _on_game_paused(_reason: int, _connected_count: int) -> void:
	# Music fade + cue disarm ride the PAUSED phase_changed that follows.
	play_sfx(&"sfx-pause")


func _on_game_resumed(_phase_value: int, _time_left_ms: int) -> void:
	# The fresh-deadline phase_changed that follows re-arms the cue.
	play_sfx(&"sfx-unpause")


func _on_chat_message(sender_peer_id: int, _sender_name: String, _text: String) -> void:
	if sender_peer_id == get_tree().get_multiplayer().get_unique_id():
		return
	play_sfx(&"sfx-chat-pop", randf_range(1.0 - CHAT_POP_JITTER, 1.0 + CHAT_POP_JITTER))


func _on_kudos_total_changed(_drawing_id: String, _total: int) -> void:
	# Global by owner decision: kudos_total_changed fires on every peer.
	play_sfx(&"sfx-kudos")


func _on_roster_updated(players: Array) -> void:
	# Lobby joins/leaves have no dedicated signals - diff the roster size.
	# In-game changes use the specific Slice 9/13 signals below instead
	# (dropped players stay IN the roster, so a count-diff misses them).
	if _route != Routes.LOBBY:
		_lobby_roster_count = players.size()
		return
	var prev := _lobby_roster_count
	_lobby_roster_count = players.size()
	if prev < 0:
		return  # own-arrival snapshot is silent
	if players.size() > prev:
		play_sfx(&"sfx-player-join")
	elif players.size() < prev:
		play_sfx(&"sfx-player-leave")


func _on_player_gained(_platform_id: String, _display_name: String) -> void:
	if _route == Routes.ROUND:
		play_sfx(&"sfx-player-join")


func _on_player_lost(_platform_id: String, _display_name: String) -> void:
	if _route == Routes.ROUND:
		play_sfx(&"sfx-player-leave")


func _on_round_resolved(_result: Dictionary) -> void:
	play_sfx(&"s4-winner")


func _on_judge_pick_latched() -> void:
	play_sfx(&"sfx-judge-latch")


func _on_reveal_beat_started(_index: int, _drawing_id: String, _beat_secs: float) -> void:
	# One curtain-pull per revealed canvas (ONE_AT_A_TIME beats; polish A2).
	play_sfx(&"sfx-reveal")


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		(node as BaseButton).pressed.connect(_on_button_pressed.bind(node))


func _on_button_pressed(btn: BaseButton) -> void:
	# Opt-out/override via meta: "none" = silent (cards, kudos - they have
	# their own sounds), any sfx id = that sound (Done! -> ready-click).
	var override := StringName(str(btn.get_meta("click_sfx", "")))
	if override == &"none":
		return
	if override != &"":
		play_sfx(override)
		return
	if btn.toggle_mode:
		play_sfx(&"sfx-toggle-on" if btn.button_pressed else &"sfx-toggle-off")
	else:
		play_sfx(&"sfx-button-press")
