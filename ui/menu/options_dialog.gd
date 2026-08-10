class_name OptionsDialog
extends AcceptDialog
## Slice 21: the game's first options surface - audio volumes only for now
## (owner D3). Paper skin rides the theme's AcceptDialog styling (Slice 13
## precedent). Built in code: the content is one shared AudioSettingsPanel.


func _ready() -> void:
	title = "Options"
	get_ok_button().text = "Done"
	min_size = Vector2i(380, 210)
	var panel := AudioSettingsPanel.new()
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 12.0
	panel.offset_top = 12.0
	panel.offset_right = -12.0
	panel.offset_bottom = -56.0
	add_child(panel)


func open() -> void:
	popup_centered()
