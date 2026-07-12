class_name TestCollectionScenes
extends GdUnitTestSuite
## Slice 8 UI tests (TDD §11): screen loads the seeded index into cards,
## empty state shows for a fresh store, the viewer's action signals fire,
## missing-doc husks degrade to Delete-only, and the confirmed delete flow
## updates index + grid. Runs against a sandbox collection root.

const SCREEN: PackedScene = preload("res://ui/collection/collection_screen.tscn")
const CARD: PackedScene = preload("res://ui/collection/collection_card.tscn")
const VIEWER: PackedScene = preload("res://ui/collection/collection_viewer.tscn")

const TEST_ROOT: String = "tests_tmp_collection_browse"


func before_test() -> void:
	CollectionStore.root_dir = TEST_ROOT
	_wipe_test_root()


func after_test() -> void:
	_wipe_test_root()
	CollectionStore.root_dir = "collection"


func _wipe_test_root() -> void:
	for file: String in Save.list_dir(TEST_ROOT + "/thumbs"):
		Save.delete(TEST_ROOT + "/thumbs/" + file)
	for file: String in Save.list_dir(TEST_ROOT):
		Save.delete(TEST_ROOT + "/" + file)


func _stroke_doc() -> Dictionary:
	return {"v": 1, "orientation": "landscape", "ops": [
		{"t": "stroke", "c": 4, "s": 1, "pts": [100.0, 100.0, 200.0, 150.0], "ts": [0.0, 0.1]},
	]}


func _seed(prompt: String, session_id: String) -> String:
	return CollectionStore.save_drawing(_stroke_doc(), prompt, session_id,
			CollectionStore.SOURCE_KUDOS)


func _instantiate_screen() -> Control:
	var screen: Control = auto_free(SCREEN.instantiate())
	add_child(screen)
	return screen


func test_screen_loads_seeded_items_as_cards_newest_first() -> void:
	_seed("first", "s1")
	_seed("second", "s2")
	var third: String = _seed("third", "s3")
	var screen: Control = _instantiate_screen()
	var grid: GridContainer = screen.find_child("Grid", true, false)
	assert_int(grid.get_child_count()).is_equal(3)
	assert_str((grid.get_child(0) as CollectionCard).entry.id).is_equal(third)
	assert_bool((screen.find_child("EmptyState", true, false) as Label).visible).is_false()
	# The lazy pump fills thumbs a few per frame.
	for i: int in range(3):
		screen._process(0.016)
	assert_object((grid.get_child(0) as CollectionCard).find_child("Thumb", true, false)
			.texture).is_not_null()


func test_empty_store_shows_empty_state() -> void:
	var screen: Control = _instantiate_screen()
	assert_bool((screen.find_child("EmptyState", true, false) as Label).visible).is_true()
	assert_bool((screen.find_child("Scroll", true, false) as ScrollContainer).visible).is_false()


func test_card_emits_pressed_with_its_id() -> void:
	var entry := CollectionIndexEntry.new()
	entry.id = "card-id"
	entry.prompt = "sleepy aardvark"
	var card: CollectionCard = auto_free(CARD.instantiate())
	card.entry = entry
	add_child(card)
	var received: Array[String] = []
	card.card_pressed.connect(func(id: String) -> void: received.append(id))
	card.pressed.emit()
	assert_array(received).contains_exactly(["card-id"])
	assert_str(card.tooltip_text).is_equal("sleepy aardvark")


func test_viewer_actions_fire_and_missing_doc_is_delete_only() -> void:
	var viewer: CollectionViewer = auto_free(VIEWER.instantiate())
	add_child(viewer)
	var entry := CollectionIndexEntry.new()
	entry.id = "item-x"
	entry.prompt = "grumpy newt"
	entry.saved_at = "2026-07-07T12:00:00"
	var doc: DrawingDoc = DrawingDoc.from_dict(_stroke_doc())
	var fired: Array[String] = []
	viewer.export_requested.connect(func(id: String) -> void: fired.append("export:" + id))
	viewer.share_requested.connect(func(id: String) -> void: fired.append("share:" + id))
	viewer.delete_requested.connect(func(id: String) -> void: fired.append("delete:" + id))
	viewer.open(entry, doc)
	assert_bool(viewer.visible).is_true()
	(viewer.find_child("ExportButton", true, false) as Button).pressed.emit()
	(viewer.find_child("ShareButton", true, false) as Button).pressed.emit()
	(viewer.find_child("DeleteButton", true, false) as Button).pressed.emit()
	assert_array(fired).contains_exactly(["export:item-x", "share:item-x", "delete:item-x"])
	# Missing doc: placeholder replaces the raster; Delete stays enabled.
	viewer.open(entry, null)
	assert_bool((viewer.find_child("MissingLabel", true, false) as Label).visible).is_true()
	assert_bool((viewer.find_child("ExportButton", true, false) as Button).disabled).is_true()
	assert_bool((viewer.find_child("ShareButton", true, false) as Button).disabled).is_true()
	assert_bool((viewer.find_child("ReplayButton", true, false) as Button).disabled).is_true()
	assert_bool((viewer.find_child("DeleteButton", true, false) as Button).disabled).is_false()


func test_viewer_replay_plays_then_returns_to_still() -> void:
	var viewer: CollectionViewer = auto_free(VIEWER.instantiate())
	add_child(viewer)
	var entry := CollectionIndexEntry.new()
	entry.id = "item-r"
	entry.prompt = "replayable"
	viewer.open(entry, DrawingDoc.from_dict(_stroke_doc()))
	var replay_button: Button = viewer.find_child("ReplayButton", true, false)
	replay_button.pressed.emit()
	assert_str(replay_button.text).is_equal("Skip")
	viewer._process(60.0)   # one huge step finishes the 0.1 s stroke
	assert_str(replay_button.text).is_equal("Replay")   # back on the still


func test_confirmed_delete_updates_index_grid_and_chrome() -> void:
	_seed("keep a", "sa")
	var middle: String = _seed("delete me", "sb")
	_seed("keep c", "sc")
	var screen: Control = _instantiate_screen()
	screen._open_viewer(middle)
	screen._on_delete_requested(middle)   # opens the confirm dialog
	screen._on_delete_confirmed()         # user confirms
	await get_tree().process_frame        # card queue_free settles
	var grid: GridContainer = screen.find_child("Grid", true, false)
	assert_int(grid.get_child_count()).is_equal(2)
	assert_int(CollectionStore.list_entries().size()).is_equal(2)
	assert_bool(Save.file_exists("%s/%s.json" % [TEST_ROOT, middle])).is_false()
	assert_bool((screen.find_child("Viewer", true, false) as CollectionViewer).visible)\
			.is_false()
	assert_str((screen.find_child("CountLabel", true, false) as Label).text)\
			.is_equal("2 drawings")
