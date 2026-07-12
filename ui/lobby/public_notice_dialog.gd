class_name PublicNoticeDialog
extends ConfirmationDialog
## Slice 13: the 18+/unmoderated notice shown before the first public join
## (per wording version - PublicNoticeGate). Accept persists the acceptance;
## decline (Go Back or closing the dialog) persists nothing.

signal accepted()
signal declined()


func _ready() -> void:
	title = "Before you join a public game"
	ok_button_text = "Accept"
	get_cancel_button().text = "Go Back"
	# Placeholder wording - Slice 15 legal pass owns the final text (§12).
	dialog_text = GameConstants.PUBLIC_NOTICE_TEXT
	confirmed.connect(_on_confirmed)
	canceled.connect(func() -> void: declined.emit())


func _on_confirmed() -> void:
	PublicNoticeGate.mark_accepted()
	accepted.emit()
