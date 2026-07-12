class_name ConfirmDialog
extends ConfirmationDialog
## Generic modal confirm (Slice 1 §7). Built for the canvas rotate flow;
## reused by Slice 8 (delete) and any later destructive action.
## Native `confirmed` signal is used as-is; `cancelled` wraps `canceled`.

signal cancelled()


func _ready() -> void:
	canceled.connect(func() -> void: cancelled.emit())


func ask(title_text: String, body: String, confirm_label: String = "OK") -> void:
	title = title_text
	dialog_text = body
	ok_button_text = confirm_label
	popup_centered()
