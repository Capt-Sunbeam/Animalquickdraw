class_name Toast
extends CanvasLayer
## Non-blocking notification toast (consistency guide §7). Screens
## instantiate ui/shared/toast.tscn once and call show_message /
## show_error. Messages queue; each shows for TOAST_SEC.

const TOAST_SEC: float = 2.5
const FADE_SEC: float = 0.3

var _queue: Array[Dictionary] = []
var _showing: bool = false

@onready var _panel: PanelContainer = %ToastPanel
@onready var _label: Label = %ToastLabel


func _ready() -> void:
	_panel.visible = false


func show_message(text: String) -> void:
	_enqueue(text, false)


func show_error(text: String) -> void:
	_enqueue(text, true)


func _enqueue(text: String, is_error: bool) -> void:
	_queue.append({"text": text, "error": is_error})
	if not _showing:
		_show_next()


func _show_next() -> void:
	if _queue.is_empty():
		_showing = false
		return
	_showing = true
	var item: Dictionary = _queue.pop_front()
	_label.text = str(item["text"])
	_label.modulate = Color(1.0, 0.6, 0.6) if bool(item["error"]) else Color.WHITE
	_panel.visible = true
	_panel.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(_panel, "modulate:a", 1.0, FADE_SEC)
	tween.tween_interval(TOAST_SEC)
	tween.tween_property(_panel, "modulate:a", 0.0, FADE_SEC)
	tween.tween_callback(_on_toast_done)


func _on_toast_done() -> void:
	_panel.visible = false
	_show_next()
