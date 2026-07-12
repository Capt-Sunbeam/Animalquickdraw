class_name LateJoinWaitBanner
extends Control
## Spectator banner (Slice 9 TDD §7): floats over the phase screen while
## this peer watches rather than draws - a late joiner waiting for their
## activation round, or a mid-DRAWING rejoiner sitting the round out.
## Never blocks input; reactions/kudos/chat stay live underneath (§9:
## spectators participate socially right away).

@onready var _label: Label = %BannerLabel


func _ready() -> void:
	visible = false


func show_waiting(text: String) -> void:
	_label.text = text
	visible = true
	move_to_front()


func hide_waiting() -> void:
	visible = false
