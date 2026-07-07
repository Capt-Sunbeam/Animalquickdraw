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

@onready var _title: Label = %MenuTitle
@onready var _close_button: Button = %CloseButton
@onready var _pause_button: Button = %PauseButton
@onready var _leave_button: Button = %LeaveButton


func _ready() -> void:
	visible = false
	_close_button.pressed.connect(close)
	_pause_button.pressed.connect(_on_pause_pressed)
	_leave_button.pressed.connect(_on_leave_pressed)
	_pause_button.visible = Session.is_host()
	_refresh()


func setup(client: SessionClient) -> void:
	_client = client


func toggle() -> void:
	if _paused:
		return   # forced visible while paused; the host resumes, not Esc
	visible = not visible
	if not visible:
		_reset_leave_confirm()


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


func _refresh() -> void:
	if _paused:
		_title.text = "Game paused" if Session.is_host() else "Host paused the game"
		_pause_button.text = "Resume game"
		_close_button.visible = false
	else:
		_title.text = "Menu"
		_pause_button.text = "Pause game"
		_close_button.visible = true