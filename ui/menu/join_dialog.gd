class_name JoinDialog
extends ConfirmationDialog
## Room-code entry dialog (Slice 2 TDD §7). Uppercases and trims the code;
## the owning screen wires join_requested to Session.join_session.

signal join_requested(code: String)

@onready var _code_edit: LineEdit = %CodeEdit


func _ready() -> void:
	get_ok_button().text = "Join"
	confirmed.connect(_submit)
	_code_edit.text_submitted.connect(_on_code_submitted)


func open(default_code: String) -> void:
	_code_edit.text = default_code
	popup_centered()
	_code_edit.grab_focus()
	_code_edit.select_all()


func _on_code_submitted(_text: String) -> void:
	hide()
	_submit()


func _submit() -> void:
	var code: String = _code_edit.text.strip_edges().to_upper()
	if not code.is_empty():
		join_requested.emit(code)
