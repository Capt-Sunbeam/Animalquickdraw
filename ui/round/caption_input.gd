class_name CaptionInput
extends HBoxContainer
## One-line anonymous caption entry for the drawing phase (Slice 5 TDD §7).
## Collapsed to a chip until clicked; Enter releases focus back to drawing;
## never persists anywhere. Hidden entirely when comments are disabled.
## Client pre-censors for niceness - the HOST censor is authoritative (§13).

@onready var _chip: Button = %CaptionChip
@onready var _edit: LineEdit = %CaptionEdit
@onready var _counter: Label = %CaptionCounter


func _ready() -> void:
	_edit.max_length = GameConstants.CAPTION_MAX_CHARS
	_edit.visible = false
	_counter.visible = false
	_chip.pressed.connect(_on_chip_pressed)
	_edit.text_changed.connect(_on_text_changed)
	_edit.text_submitted.connect(func(_text: String) -> void: _edit.release_focus())


## The pre-censored caption to ride the submission payload.
func caption_text() -> String:
	return TextFilter.censor(_edit.text.strip_edges())


func _on_chip_pressed() -> void:
	_chip.visible = false
	_edit.visible = true
	_counter.visible = true
	_on_text_changed(_edit.text)
	_edit.grab_focus()


func _on_text_changed(text: String) -> void:
	_counter.text = "%d/%d" % [text.length(), GameConstants.CAPTION_MAX_CHARS]
