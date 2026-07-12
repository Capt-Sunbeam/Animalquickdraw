class_name GameMenu
extends Control
## In-game Esc menu + pause overlay (Slice 6, owner decision 2026-07-06).
## Esc toggles the menu; the host can Pause (freezes the phase clock for
## everyone via GameSession.pause) and anyone can Leave (host leaving ends
## the session - existing Slice 2 semantics until Slice 9 upgrades them).
## While the game is paused the overlay is forced visible on every peer.

const LEAVE_CONFIRM_HOST: String = "Really leave? This ends the game for everyone."
const LEAVE_CONFIRM_CLIENT: String = "Really leave the game?"

var _client: SessionClient = null
var _paused: bool = false
var _confirming_leave: bool = false
var _kick_confirm_peer: int = 0   # Slice 13: two-click confirm target

@onready var _title: Label = %MenuTitle
@onready var _close_button: Button = %CloseButton
@onready var _pause_button: Button = %PauseButton
@onready var _leave_button: Button = %LeaveButton
@onready var _kick_header: Label = %KickHeader
@onready var _kick_rows: VBoxContainer = %KickRows


func _ready() -> void:
	visible = false
	_close_button.pressed.connect(close)
	_pause_button.pressed.connect(_on_pause_pressed)
	_leave_button.pressed.connect(_on_leave_pressed)
	_pause_button.visible = Session.is_host()
	# Slice 13: the Esc menu is the in-game kick surface (host only).
	_kick_header.visible = Session.is_host()
	_kick_rows.visible = Session.is_host()
	if Session.is_host():
		EventBus.roster_updated.connect(func(_players: Array) -> void:
			_rebuild_kick_rows())
		_rebuild_kick_rows()
	_refresh()


func setup(client: SessionClient) -> void:
	_client = client


func toggle() -> void:
	if _paused:
		return   # forced visible while paused; the host resumes, not Esc
	visible = not visible
	if not visible:
		_reset_leave_confirm()
	elif Session.is_host():
		_rebuild_kick_rows()   # Slice 13: opening resets any armed kick confirm


func close() -> void:
	if _paused:
		return
	visible = false
	_reset_leave_confirm()


## RoundRoot calls these from phase_changed(PAUSED) / the resume broadcast.
func show_paused() -> void:
	_paused = true
	visible = true
	_refresh()


func hide_paused() -> void:
	if not _paused:
		return
	_paused = false
	visible = false
	_reset_leave_confirm()
	_refresh()


func _on_pause_pressed() -> void:
	if _client == null:
		return
	if _paused:
		_client.request_resume()
	else:
		_client.request_pause()   # PAUSED broadcast flips the overlay on


## Two-click confirm - no dialog dependency, impossible to fat-finger.
func _on_leave_pressed() -> void:
	if not _confirming_leave:
		_confirming_leave = true
		_leave_button.text = LEAVE_CONFIRM_HOST if Session.is_host() else LEAVE_CONFIRM_CLIENT
		return
	Session.leave()


func _reset_leave_confirm() -> void:
	_confirming_leave = false
	_leave_button.text = "Leave game"


# --- Slice 13: host kick rows (connected, non-host players) ---


func _rebuild_kick_rows() -> void:
	for child: Node in _kick_rows.get_children():
		child.queue_free()
	_kick_confirm_peer = 0
	for p: Roster.PlayerState in Session.roster.players_in_join_order():
		if p.peer_id == 1 or not p.is_connected:
			continue
		_kick_rows.add_child(_build_kick_row(p))


func _build_kick_row(p: Roster.PlayerState) -> HBoxContainer:
	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = p.display_name   # plain text - never markup (audit rule)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(name_label)
	var kick := Button.new()
	kick.text = "Kick"
	kick.pressed.connect(_on_kick_pressed.bind(p.peer_id, kick))
	row.add_child(kick)
	return row


## Two-click confirm (Leave-button precedent - no dialog dependency). The
## armed label warns when this kick drops the roster below minimum and will
## pause the game (TDD 13 §10).
func _on_kick_pressed(peer_id: int, button: Button) -> void:
	if _kick_confirm_peer != peer_id:
		_kick_confirm_peer = peer_id
		var will_pause: bool = \
				Session.roster.connected_count() - 1 < GameConstants.MIN_PLAYERS
		button.text = "Sure? (pauses game)" if will_pause else "Sure? (no rejoin)"
		return
	Session.kick_player(peer_id)   # the roster broadcast rebuilds these rows


func _refresh() -> void:
	if _paused:
		_title.text = "Game paused" if Session.is_host() else "Host paused the game"
		_pause_button.text = "Resume game"
		_close_button.visible = false
	else:
		_title.text = "Menu"
		_pause_button.text = "Pause game"
		_close_button.visible = true