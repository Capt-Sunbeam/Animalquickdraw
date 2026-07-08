class_name PauseOverlay
extends Control
## Below-minimum pause overlay (Slice 9 TDD §7): dims the frozen phase
## screen, shows "Waiting for players... (n/3)", and gives the host the
## End-game-now escape (two-click confirm, GameMenu pattern). Chat stays
## usable - the overlay covers only the phase area, and RoundRoot keeps the
## chat outside it. Host-menu pauses use GameMenu instead; RoundRoot picks
## the surface by NetIds.PauseReason.

var _client: SessionClient = null
var _confirming_end: bool = false

@onready var _count_label: Label = %CountLabel
@onready var _end_button: Button = %EndButton


func _ready() -> void:
	visible = false
	_end_button.pressed.connect(_on_end_pressed)
	_end_button.visible = Session.is_host()
	# A further drop/rejoin while paused only changes the counter; the
	# roster broadcast is the update signal (pause itself is idempotent).
	EventBus.roster_updated.connect(func(_players: Array) -> void:
		if visible:
			_refresh_count())


func setup(client: SessionClient) -> void:
	_client = client


func open(connected_count: int) -> void:
	visible = true
	move_to_front()   # above any phase screen added to the same parent
	_reset_end_confirm()
	_set_count(connected_count)


func close() -> void:
	visible = false
	_reset_end_confirm()


func _refresh_count() -> void:
	_set_count(Session.roster.connected_count())


func _set_count(connected_count: int) -> void:
	_count_label.text = "Waiting for players... (%d/%d)" \
			% [connected_count, GameConstants.MIN_PLAYERS]


## Two-click confirm - no dialog dependency, impossible to fat-finger.
func _on_end_pressed() -> void:
	if not _confirming_end:
		_confirming_end = true
		_end_button.text = "End with results so far?"
		return
	if _client != null:
		_client.request_end_game_early()


func _reset_end_confirm() -> void:
	_confirming_end = false
	_end_button.text = "End game now"
