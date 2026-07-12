extends Control
## Slice 13: public lobby browser (TDD 13 §5/§7). Screen-local state machine
## (no autoload - the list is UI-local); data comes from
## Platform.request_lobby_list (awaitable coroutine, the Slice 12 contract
## style), rows parse strictly via LobbyListing, filters run client-side
## over the parsed rows. Join hands off to Session.join_session_by_lobby
## (the Slice 12 invite-path seam) behind the PublicNoticeGate.

enum BrowserState { IDLE, REQUESTING, LISTED, FAILED, NOTICE_GATE, JOINING }

const MODE_LABELS: Dictionary = {
	"default": "Default", "streamlined": "Streamlined",
	"social": "Social", "custom": "Custom",
}
const POOL_LABELS: Dictionary = {"builtin": "Built-in", "player": "Player-made"}

var _state: BrowserState = BrowserState.IDLE
var _listings: Array[LobbyListing] = []
var _last_request_ms: int = -1_000_000   # first refresh always allowed
var _pending_join: LobbyListing = null

@onready var _back_button: Button = %BackButton
@onready var _refresh_button: Button = %RefreshButton
@onready var _mode_option: OptionButton = %ModeOption
@onready var _space_check: CheckBox = %SpaceCheck
@onready var _rows: VBoxContainer = %Rows
@onready var _status_label: Label = %StatusLabel
@onready var _retry_button: Button = %RetryButton
@onready var _notice_dialog: PublicNoticeDialog = %NoticeDialog
@onready var _toast: Toast = %Toast


func _ready() -> void:
	_back_button.pressed.connect(func() -> void: Nav.goto(Routes.MENU))
	_refresh_button.pressed.connect(_refresh)
	_retry_button.pressed.connect(_refresh)
	_mode_option.clear()
	_mode_option.add_item("All modes")
	_mode_option.set_item_metadata(0, "")
	for mode: String in LobbyListing.MODES:
		_mode_option.add_item(str(MODE_LABELS[mode]))
		_mode_option.set_item_metadata(_mode_option.item_count - 1, mode)
	_mode_option.item_selected.connect(func(_index: int) -> void: _rebuild_rows())
	_space_check.toggled.connect(func(_on: bool) -> void: _rebuild_rows())
	_notice_dialog.accepted.connect(_on_notice_accepted)
	_notice_dialog.declined.connect(_on_notice_declined)
	_refresh()


func _refresh() -> void:
	if _state == BrowserState.REQUESTING or _state == BrowserState.JOINING:
		return
	var now: int = Time.get_ticks_msec()
	if now - _last_request_ms < int(GameConstants.BROWSER_REFRESH_COOLDOWN_SEC * 1000.0):
		return   # rate limit (button re-enables via the cooldown timer)
	_last_request_ms = now
	_set_state(BrowserState.REQUESTING)
	var result: Dictionary = await Platform.request_lobby_list()
	if not is_inside_tree():
		return   # screen swapped away mid-await
	if not bool(result.get("ok", false)):
		_set_state(BrowserState.FAILED)
		return
	_listings = []
	for entry: Variant in result.get("lobbies", []):
		if not entry is Dictionary:
			continue
		var listing: LobbyListing = LobbyListing.from_lobby_metadata(
				int(entry.get("id", 0)), entry.get("meta", {}))
		if listing != null:
			_listings.append(listing)   # malformed rows dropped, never rendered
	_set_state(BrowserState.LISTED)


func _filtered() -> Array[LobbyListing]:
	var mode_filter: String = ""
	if _mode_option.selected >= 0:
		mode_filter = str(_mode_option.get_selected_metadata())
	var out: Array[LobbyListing] = []
	for listing: LobbyListing in _listings:
		if not mode_filter.is_empty() and listing.mode != mode_filter:
			continue
		if _space_check.button_pressed and not listing.has_space():
			continue
		out.append(listing)
	return out


func _rebuild_rows() -> void:
	for child: Node in _rows.get_children():
		child.queue_free()
	if _state == BrowserState.REQUESTING or _state == BrowserState.FAILED:
		return
	var visible_rows: Array[LobbyListing] = _filtered()
	for listing: LobbyListing in visible_rows:
		_rows.add_child(_build_row(listing))
	if _listings.is_empty():
		_status_label.text = "No open public games - host one!"
	elif visible_rows.is_empty():
		_status_label.text = "No games match the filters."
	else:
		_status_label.text = ""


func _build_row(listing: LobbyListing) -> Control:
	var row := HBoxContainer.new()
	row.add_child(_cell(listing.name, 3.0))   # Label.text only - never markup
	row.add_child(_cell(str(MODE_LABELS.get(listing.mode, listing.mode)), 2.0))
	row.add_child(_cell("%d/%d" % [listing.players_cur, listing.players_max], 1.0))
	row.add_child(_cell("%d rounds" % listing.rounds, 1.5))
	row.add_child(_cell("%ds draw" % listing.draw_time, 1.5))
	row.add_child(_cell(str(POOL_LABELS.get(listing.pool_type, "?")), 1.5))
	var join := Button.new()
	join.text = "Join"
	# Full rows keep their information; only the action is disabled (§7).
	join.disabled = not listing.has_space()
	join.pressed.connect(_on_join_pressed.bind(listing))
	row.add_child(join)
	return row


func _cell(cell_text: String, stretch: float) -> Label:
	var label := Label.new()
	label.text = cell_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_stretch_ratio = stretch
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label


func _on_join_pressed(listing: LobbyListing) -> void:
	if _state != BrowserState.LISTED:
		return
	if PublicNoticeGate.is_accepted():
		_start_join(listing)
	else:
		_pending_join = listing
		_set_state(BrowserState.NOTICE_GATE)
		_notice_dialog.popup_centered()


func _on_notice_accepted() -> void:
	var listing: LobbyListing = _pending_join
	_pending_join = null
	if listing != null:
		_start_join(listing)


func _on_notice_declined() -> void:
	_pending_join = null
	_set_state(BrowserState.LISTED)


func _start_join(listing: LobbyListing) -> void:
	_set_state(BrowserState.JOINING)
	_status_label.text = "Joining %s..." % listing.name
	var err: Error = await Session.join_session_by_lobby(listing.lobby_id)
	if not is_inside_tree():
		return   # success navigated away (welcome -> lobby), or screen swapped
	if err != OK:
		# Browser data was advisory; the live join told the truth (§10).
		match Platform.get_last_failure_reason():
			"full":
				_toast.show_error("That game is full.")
			"not_found":
				_toast.show_error("That game no longer exists.")
			"version_mismatch":
				_toast.show_error("Your game versions don't match - update Animal Quickdraw.")
			_:
				_toast.show_error("Couldn't join (%s)." % error_string(err))
		_set_state(BrowserState.LISTED)
	# A post-connect handshake reject (full/kicked raced us) closes to the
	# MENU with its reason toast/dialog - deviation from the TDD's
	# return-to-Listed, consistent with every other join path (impl notes).


func _set_state(new_state: BrowserState) -> void:
	_state = new_state
	_refresh_button.disabled = new_state == BrowserState.REQUESTING \
			or new_state == BrowserState.JOINING
	_retry_button.visible = new_state == BrowserState.FAILED
	match new_state:
		BrowserState.REQUESTING:
			_status_label.text = "Looking for games..."
		BrowserState.FAILED:
			_status_label.text = "Couldn't reach Steam - try again."
		BrowserState.LISTED:
			_arm_refresh_cooldown()
	_rebuild_rows()


## Refresh stays disabled for the cooldown remainder after results land
## (§7: disabled during request + cooldown).
func _arm_refresh_cooldown() -> void:
	var elapsed: float = float(Time.get_ticks_msec() - _last_request_ms) / 1000.0
	var remaining: float = GameConstants.BROWSER_REFRESH_COOLDOWN_SEC - elapsed
	if remaining <= 0.0:
		return
	_refresh_button.disabled = true
	get_tree().create_timer(remaining).timeout.connect(func() -> void:
		if is_inside_tree() and _state == BrowserState.LISTED:
			_refresh_button.disabled = false)
