class_name AvatarChip
extends HBoxContainer
## The one and only way any screen renders a player identity (Slice 11 §7):
## circle avatar - or the fallback chain's name circle / house doodle - plus
## an optional name label beside it. Never re-implement the chain elsewhere.
## The tooltip always carries the full display name (cg §13 - identity never
## rests on art alone).

@export var chip_size: int = 48            # px diameter; lobby 48, in-round 26-32, wrap-up 96
@export var show_name_label: bool = true

## Below this diameter a NAME_CIRCLE shows two characters, not the shrunken
## full name (a 9-char name in a 32 px circle is noise, not identity - §7).
const TWO_CHAR_BELOW_PX: int = 48

var _bound_platform_id: String = ""        # non-empty = live roster mode
var _bound_fallback_name: String = ""      # used when the roster lookup misses
var _pending_render: Callable = Callable() # bind before tree entry (list rows)

@onready var _face_slot: Control = %FaceSlot
# Named ChipNameLabel (not NameLabel) so host screens' own name labels stay
# unambiguous under recursive find_child lookups.
@onready var _name_label: Label = %ChipNameLabel


func _ready() -> void:
	_face_slot.custom_minimum_size = Vector2(chip_size, chip_size)
	_name_label.visible = show_name_label
	EventBus.avatar_updated.connect(_on_avatar_updated)
	if _pending_render.is_valid():
		_pending_render.call()
		_pending_render = Callable()


## Static mode: render from raw values (wrap-up cards after session end,
## previews). No auto-refresh. Callable before the chip enters the tree
## (list-row builders configure detached rows) - rendering defers to _ready.
func set_player(display_name: String, platform_id: String, avatar_doc: Dictionary) -> void:
	_bound_platform_id = ""
	if not is_node_ready():
		_pending_render = set_player.bind(display_name, platform_id, avatar_doc)
		return
	_render(AvatarResolver.resolve(avatar_doc, display_name, platform_id))


## Live mode: roster lookup + auto-refresh on EventBus.avatar_updated for
## this player only. fallback_name keeps chips honest on surfaces that carry
## their own name data when the roster misses (tests, teardown races).
func bind_platform_id(platform_id: String, fallback_name: String = "") -> void:
	_bound_platform_id = platform_id
	_bound_fallback_name = fallback_name
	if not is_node_ready():
		_pending_render = _render_from_roster
		return
	_render_from_roster()


func _on_avatar_updated(platform_id: String) -> void:
	if not _bound_platform_id.is_empty() and platform_id == _bound_platform_id:
		_render_from_roster()


func _render_from_roster() -> void:
	var player: Roster.PlayerState = Session.roster.get_by_platform_id(_bound_platform_id)
	if player == null:
		_render(AvatarResolver.resolve({}, _bound_fallback_name, _bound_platform_id))
		return
	_render(AvatarResolver.resolve(player.avatar_doc, player.display_name,
			player.platform_id))


func _render(resolved: AvatarResolver.Resolved) -> void:
	for child: Node in _face_slot.get_children():
		child.queue_free()
	tooltip_text = resolved.display_name
	_name_label.text = resolved.display_name
	match resolved.kind:
		AvatarResolver.Kind.DRAWN, AvatarResolver.Kind.HOUSE:
			var texture: ImageTexture = AvatarTextureCache.get_texture(resolved.doc)
			if texture == null:
				_face_slot.add_child(_build_name_circle(resolved.display_name))
				return
			var rect := TextureRect.new()
			rect.texture = texture
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_face_slot.add_child(rect)
		AvatarResolver.Kind.NAME_CIRCLE:
			_face_slot.add_child(_build_name_circle(resolved.display_name))


## Fallback #2: theme-styled filled circle with the name (or its first two
## characters below TWO_CHAR_BELOW_PX; the tooltip carries the full name).
func _build_name_circle(display_name: String) -> Control:
	var circle := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color.from_hsv(
			float(absi(display_name.hash()) % 360) / 360.0, 0.45, 0.72)
	style.set_corner_radius_all(int(chip_size / 2.0))
	circle.add_theme_stylebox_override("panel", style)
	circle.set_anchors_preset(Control.PRESET_FULL_RECT)
	circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var text := Label.new()
	var short: bool = chip_size < TWO_CHAR_BELOW_PX
	text.text = display_name.left(2) if short else display_name
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.clip_text = true
	text.add_theme_color_override("font_color", Color.WHITE)
	text.add_theme_font_size_override("font_size",
			maxi(10, int(chip_size / (2.2 if short else 4.5))))
	circle.add_child(text)
	return circle
