class_name CollectionCard
extends Button
## One collection grid cell (Slice 8 TDD §7): thumbnail letterboxed in a
## uniform box + ellipsized prompt with full-prompt tooltip. The thumb
## texture arrives async from the screen's lazy pump; until then a
## placeholder shows. missing_doc cards stay clickable - the viewer offers
## Delete as the only action for husks (§10).

signal card_pressed(item_id: String)

var entry: CollectionIndexEntry = null
var missing_doc: bool = false

@onready var _thumb: TextureRect = %Thumb
@onready var _placeholder: Label = %Placeholder
@onready var _prompt: Label = %Prompt


func _ready() -> void:
	pressed.connect(func() -> void: card_pressed.emit(entry.id if entry != null else ""))
	if entry != null:
		_prompt.text = entry.prompt
		tooltip_text = entry.prompt


func set_thumb(texture: Texture2D) -> void:
	if texture == null:
		missing_doc = true
		_placeholder.text = "(missing drawing)"
		return
	_thumb.texture = texture
	_placeholder.visible = false
