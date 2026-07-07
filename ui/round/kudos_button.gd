class_name KudosButton
extends Button
## Per-cell kudos control (Slice 4 TDD §7). NO optimistic spend: press ->
## PENDING spinner-state; the wallet decrements only when the host's private
## confirm lands (EventBus.kudos_given). A dropped request (e.g. lost the
## last-kudos race) simply never confirms - the pending timeout re-enables
## the button; the wallet never went negative because nothing was deducted.

signal kudos_requested()

const PENDING_TIMEOUT_SEC: float = 2.0

enum KudosState { IDLE, PENDING, GIVEN }

var drawing_id: String = ""
var own_drawing: bool = false:
	set(value):
		own_drawing = value
		_refresh()
var gate_open: bool = false:
	set(value):
		gate_open = value
		_refresh()

var _state: KudosState = KudosState.IDLE
var _total: int = 0                # public per-drawing kudos total
var _pending_timer: Timer


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(0, 36)
	add_theme_font_size_override("font_size", 15)
	_pending_timer = Timer.new()
	_pending_timer.one_shot = true
	_pending_timer.wait_time = PENDING_TIMEOUT_SEC
	_pending_timer.timeout.connect(_on_pending_timeout)
	add_child(_pending_timer)
	pressed.connect(_on_pressed)
	EventBus.kudos_total_changed.connect(_on_total_changed)
	EventBus.kudos_given.connect(_on_kudos_given)
	EventBus.kudos_wallet_changed.connect(func(_remaining: int) -> void: _refresh())
	EventBus.roster_updated.connect(func(_players: Array) -> void: _refresh())
	_refresh()


func _on_pressed() -> void:
	if _state != KudosState.IDLE:
		return
	_state = KudosState.PENDING
	_pending_timer.start()
	_refresh()
	kudos_requested.emit()


func _on_kudos_given(id: String, _remaining: int) -> void:
	if id != drawing_id:
		return
	_pending_timer.stop()
	_state = KudosState.GIVEN
	_refresh()


func _on_total_changed(id: String, total: int) -> void:
	if id != drawing_id:
		return
	_total = total
	_refresh()


func _on_pending_timeout() -> void:
	if _state == KudosState.PENDING:
		_state = KudosState.IDLE   # host dropped the request - re-enable
		_refresh()


func _wallet() -> Roster.PlayerState:
	return Session.local_player()


func _refresh() -> void:
	var badge: String = (" ×%d" % _total) if _total > 0 else ""
	var me: Roster.PlayerState = _wallet()
	var remaining: int = (me.kudos_granted - me.kudos_spent) if me != null else 0
	tooltip_text = ""
	match _state:
		KudosState.PENDING:
			text = "🏅 …" + badge
			disabled = true
		KudosState.GIVEN:
			text = "🏅 Given!" + badge
			disabled = true
		_:
			text = "🏅 Kudos" + badge
			disabled = own_drawing or not gate_open or remaining <= 0
			if me != null and me.kudos_granted == 0:
				tooltip_text = "Kudos are off for this game"
