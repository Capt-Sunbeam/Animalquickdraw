class_name ReactionBar
extends HBoxContainer
## Six anonymous emoji toggles with aggregate count badges (Slice 4 TDD §7).
## Counts render exclusively from EventBus.reaction_counts_changed (host
## truth); the local pressed-state is optimistic and cheap to be wrong - the
## host validates every toggle. No names anywhere - aggregate only (§11).

signal reaction_toggled(reaction: NetIds.Reaction, active: bool)

## Button order = NetIds.Reaction order: LAUGH, LOVE, WOW, DISGUST, CRY, FIRE.
const EMOJI: Array[String] = ["😂", "❤️", "😮", "🤢", "😭", "🔥"]

var drawing_id: String = ""
var interactive: bool = false:
	set(value):
		interactive = value
		_apply_interactive()

var _buttons: Array[Button] = []
var _counts: Dictionary = {}       # Reaction -> int (host aggregate)
var _last_toggle_ms: int = 0


func _ready() -> void:
	# Roomy targets + legible glyphs (owner feedback 2026-07-06: the first
	# pass was cramped and hard to see).
	add_theme_constant_override("separation", 4)
	for i: int in EMOJI.size():
		var btn := Button.new()
		btn.toggle_mode = true
		btn.theme_type_variation = &"EmojiButton"
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(46, 40)
		btn.add_theme_font_size_override("font_size", 19)
		btn.text = EMOJI[i]
		btn.toggled.connect(_on_button_toggled.bind(i))
		add_child(btn)
		_buttons.append(btn)
	_apply_interactive()
	EventBus.reaction_counts_changed.connect(_on_counts_changed)


func _on_counts_changed(id: String, counts: Dictionary) -> void:
	if id != drawing_id:
		return
	_counts = counts
	for i: int in _buttons.size():
		var n: int = int(_counts.get(i, 0))
		_buttons[i].text = ("%s%d" % [EMOJI[i], n]) if n > 0 else EMOJI[i]


func _apply_interactive() -> void:
	for btn: Button in _buttons:
		btn.disabled = not interactive


func _on_button_toggled(pressed: bool, index: int) -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_toggle_ms < GameConstants.REACTION_DEBOUNCE_MSEC:
		_buttons[index].set_pressed_no_signal(not pressed)   # revert - debounced
		return
	_last_toggle_ms = now
	reaction_toggled.emit(index as NetIds.Reaction, pressed)
