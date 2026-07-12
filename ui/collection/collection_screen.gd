extends Control
## Collection browser (Slice 8 TDD §7): newest-first grid of saved drawings
## with lazy thumbnail loading, a viewer overlay (replay/export/share/
## delete), and a friendly empty state. Entirely local-first - no session,
## no RPCs; reachable only from the main menu (§3). The screen owns all its
## state and is freed on navigation (no new autoloads, §8).

const CARD_SCENE: PackedScene = preload("res://ui/collection/collection_card.tscn")

var _cards: Dictionary = {}            # item_id -> CollectionCard
var _thumb_queue: PackedStringArray = PackedStringArray()   # ids awaiting thumbs

@onready var _back_button: Button = %BackButton
@onready var _count_label: Label = %CountLabel
@onready var _scroll: ScrollContainer = %Scroll
@onready var _grid: GridContainer = %Grid
@onready var _empty_state: Label = %EmptyState
@onready var _viewer: CollectionViewer = %Viewer
@onready var _confirm: ConfirmDialog = %Confirm
@onready var _toast: Toast = %Toast


func _ready() -> void:
	_back_button.pressed.connect(func() -> void: Nav.goto(Routes.MENU))
	_viewer.closed.connect(_viewer.close)
	_viewer.export_requested.connect(_on_export_requested)
	_viewer.share_requested.connect(_on_share_requested)
	_viewer.delete_requested.connect(_on_delete_requested)
	_confirm.confirmed.connect(_on_delete_confirmed)
	_load_index()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _viewer.visible:
			_viewer.close()
		else:
			Nav.goto(Routes.MENU)
		get_viewport().set_input_as_handled()


func _load_index() -> void:
	var entries: Array[CollectionIndexEntry] = CollectionStore.list_entries()
	for entry: CollectionIndexEntry in entries:
		var card: CollectionCard = CARD_SCENE.instantiate()
		card.entry = entry
		card.card_pressed.connect(_open_viewer)
		_grid.add_child(card)
		_cards[entry.id] = card
		_thumb_queue.append(entry.id)
	_refresh_chrome()


## Lazy thumb pump: a bounded number of loads/regenerations per frame so a
## wiped cache repopulates without a frozen frame (§10 performance).
func _process(_delta: float) -> void:
	for i: int in range(GameConstants.THUMB_LOADS_PER_FRAME):
		if _thumb_queue.is_empty():
			return
		var id: String = _thumb_queue[0]
		_thumb_queue.remove_at(0)
		var card: CollectionCard = _cards.get(id)
		if card == null:
			continue
		var img: Image = CollectionStore.get_thumb(id, card.entry.orientation)
		card.set_thumb(ImageTexture.create_from_image(img) if img != null else null)


func _refresh_chrome() -> void:
	var count: int = _cards.size()
	_count_label.text = "%d drawing%s" % [count, "" if count == 1 else "s"]
	_empty_state.visible = count == 0
	_scroll.visible = count > 0


func _open_viewer(item_id: String) -> void:
	var card: CollectionCard = _cards.get(item_id)
	if card == null:
		return
	# null doc is legal: the viewer degrades to Delete-only for husks (§10).
	_viewer.open(card.entry, CollectionStore.read_doc(item_id))


func _on_export_requested(item_id: String) -> void:
	if _export(item_id).is_empty():
		return
	_toast.show_message("Exported to the exports folder!")


## v1 sharing IS export + reveal-in-folder (brief §14 - no upload anywhere).
func _on_share_requested(item_id: String) -> void:
	var path: String = _export(item_id)
	if path.is_empty():
		return
	var err: Error = OS.shell_show_in_file_manager(Save.globalize(path), true)
	if err != OK:
		# Some Linux desktops don't honor reveal - open the folder instead.
		OS.shell_open(Save.globalize(CollectionStore.EXPORT_DIR))
	_toast.show_message("Exported to the exports folder!")


func _export(item_id: String) -> String:
	var path: String = CollectionStore.export_png(item_id)
	if path.is_empty():
		_toast.show_error("Couldn't export that drawing.")
	return path


func _on_delete_requested(_item_id: String) -> void:
	_confirm.ask("Delete this drawing?", "This can't be undone.", "Delete")


func _on_delete_confirmed() -> void:
	var id: String = _viewer.item_id()
	if id.is_empty():
		return
	if CollectionStore.delete(id) != OK:
		_toast.show_error("Couldn't delete that drawing.")
		return
	_viewer.close()
	var card: CollectionCard = _cards.get(id)
	if card != null:
		card.queue_free()
	_cards.erase(id)
	_refresh_chrome()
