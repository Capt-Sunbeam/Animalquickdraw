extends Control
## POOL_SETUP submission screen (Slice 7 TDD §7). One column per pool_id,
## built dynamically from phase data - future pool types need no UI changes.
## Local TextFilter pre-check is UX sugar only; the host re-validates every
## word (§13). The screen never infers completion locally - it advances only
## on the host's phase_changed(ROUND_INTRO).

const REASON_TEXT: Dictionary = {
	NetIds.WordRejectReason.NOT_CLEAN: "That word isn't allowed",
	NetIds.WordRejectReason.BAD_LENGTH: "Words must be 1-%d characters, one line" % GameConstants.WORD_MAX_CHARS,
	NetIds.WordRejectReason.WRONG_COUNT: "Fill every box",
	NetIds.WordRejectReason.ALREADY_SUBMITTED: "Already submitted",
}

var _client: SessionClient = null
var _share: int = 0
var _force_at_ms: int = 0
var _columns: Dictionary = {}   # pool_id -> {edits, submit, error, progress, submitted}

@onready var _header: Label = %HeaderLabel
@onready var _columns_box: HBoxContainer = %Columns
@onready var _waiting: Label = %WaitingLabel
@onready var _host_row: HBoxContainer = %HostRow
@onready var _force_button: Button = %ForceButton
@onready var _force_hint: Label = %ForceHint
@onready var _force_timer: PhaseTimer = %ForceTimer
@onready var _confirm: ConfirmDialog = %Confirm


func _ready() -> void:
	EventBus.pool_setup_progress_changed.connect(_on_progress_changed)
	EventBus.pool_words_rejected.connect(_on_words_rejected)
	_force_button.pressed.connect(_on_force_pressed)
	_confirm.confirmed.connect(_on_force_confirmed)


func setup(data: Dictionary, client: SessionClient) -> void:
	_client = client
	_share = int(data.get("share_per_player", 0))
	_force_at_ms = int(data.get("force_available_at_ms", 0))
	var display_names: Dictionary = data.get("pool_display_names", {})
	_header.text = "Fill the pools!   Submit %d word%s to each pool" \
			% [_share, "" if _share == 1 else "s"]
	_waiting.text = ""
	for pool_id: String in data.get("pool_ids", PackedStringArray()):
		_build_column(pool_id, str(display_names.get(pool_id, pool_id.capitalize())))
	# Host escape hatch (§7): the force button unlocks on the HOST's own
	# clock only - other peers just see the waiting panel (§10 clock skew).
	_host_row.visible = multiplayer.is_server()
	if _host_row.visible:
		_force_timer.start(_force_at_ms)


func _build_column(pool_id: String, display_name: String) -> void:
	var col := VBoxContainer.new()
	col.name = "Col_%s" % pool_id
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	_columns_box.add_child(col)
	var title_row := HBoxContainer.new()
	col.add_child(title_row)
	var title := Label.new()
	title.text = display_name.to_upper()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 18)
	title_row.add_child(title)
	var progress := Label.new()
	progress.name = "Progress"
	progress.text = "0 / %d" % _share
	title_row.add_child(progress)
	var edits: Array[LineEdit] = []
	for i: int in range(_share):
		var edit := LineEdit.new()
		edit.max_length = GameConstants.WORD_MAX_CHARS
		edit.placeholder_text = "word %d" % (i + 1)
		edit.text_changed.connect(func(_t: String) -> void: _refresh_column(pool_id))
		col.add_child(edit)
		edits.append(edit)
	var error := Label.new()
	error.name = "Error"
	error.visible = false
	error.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))
	error.add_theme_font_size_override("font_size", 12)
	col.add_child(error)
	var submit := Button.new()
	submit.name = "Submit"
	submit.text = "Submit %s" % display_name.to_lower()
	submit.custom_minimum_size = Vector2(0, 40)
	submit.disabled = true
	submit.pressed.connect(_on_submit_pressed.bind(pool_id))
	col.add_child(submit)
	_columns[pool_id] = {"edits": edits, "submit": submit, "error": error,
			"progress": progress, "submitted": false}


## Local pre-check (mirrors the §2 rules for UX; host is the referee).
func _refresh_column(pool_id: String) -> void:
	var col: Dictionary = _columns[pool_id]
	if bool(col["submitted"]):
		return
	var filled: int = 0
	var problem: String = ""
	for edit: LineEdit in col["edits"]:
		var word: String = edit.text.strip_edges()
		if word.is_empty():
			continue
		filled += 1
		if word.length() > GameConstants.WORD_MAX_CHARS:
			problem = REASON_TEXT[NetIds.WordRejectReason.BAD_LENGTH]
		elif not TextFilter.is_clean(word):
			problem = REASON_TEXT[NetIds.WordRejectReason.NOT_CLEAN]
	(col["progress"] as Label).text = "%d / %d" % [filled, _share]
	var error: Label = col["error"]
	error.text = problem
	error.visible = not problem.is_empty()
	(col["submit"] as Button).disabled = \
			filled < _share or not problem.is_empty()


func _on_submit_pressed(pool_id: String) -> void:
	var col: Dictionary = _columns[pool_id]
	var words := PackedStringArray()
	for edit: LineEdit in col["edits"]:
		words.append(edit.text.strip_edges())
	_set_column_locked(pool_id, true)
	if _client != null:
		_client.request_submit_pool_words(pool_id, words)


## Locks a column pending the host verdict (✓) - or unlocks it again when a
## rejection lands (tampered/stale client path; rare by construction).
func _set_column_locked(pool_id: String, locked: bool) -> void:
	var col: Dictionary = _columns[pool_id]
	col["submitted"] = locked
	for edit: LineEdit in col["edits"]:
		edit.editable = not locked
	var submit: Button = col["submit"]
	submit.disabled = locked
	if locked:
		submit.text = "Submitted ✓"
	else:
		submit.text = "Submit %s" % pool_id
		_refresh_column(pool_id)


func _on_words_rejected(pool_id: String, reason: int) -> void:
	if not _columns.has(pool_id):
		return
	_set_column_locked(pool_id, false)
	var error: Label = (_columns[pool_id] as Dictionary)["error"]
	error.text = str(REASON_TEXT.get(reason, "Rejected - try different words"))
	error.visible = true


func _on_progress_changed(progress: Array) -> void:
	var waiting := PackedStringArray()
	var done := PackedStringArray()
	for raw: Variant in progress:
		var entry: Dictionary = raw
		var name: String = str(entry.get("display_name", "?"))
		if int(entry["pools_done"]) >= int(entry["pools_total"]):
			done.append("%s ✓" % name)
		else:
			waiting.append("%s (%d/%d)" % [name,
					int(entry["pools_done"]), int(entry["pools_total"])])
	var parts := PackedStringArray()
	if not waiting.is_empty():
		parts.append("Waiting on: %s" % ", ".join(waiting))
	if not done.is_empty():
		parts.append(", ".join(done))
	_waiting.text = "      ".join(parts)


func _process(_delta: float) -> void:
	if not _host_row.visible:
		return
	var unlocked: bool = PhaseTimer._local_now_ms() >= _force_at_ms
	_force_button.disabled = not unlocked
	_force_hint.visible = not unlocked
	_force_timer.visible = not unlocked


func _on_force_pressed() -> void:
	_confirm.ask("Start without everyone?",
			"Start without everyone's words? Missing words will be filled in automatically.",
			"Start")


func _on_force_confirmed() -> void:
	if _client != null:
		_client.force_continue_pool_setup()
