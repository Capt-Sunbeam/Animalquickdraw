extends Node
## Autoload "Nav" - screen navigation via Routes constants (skeleton guide
## §3.6). Instant swap now, transition polish later. Frees the old screen
## and instantiates the new one (via SceneTree.change_scene_to_file).
## In-round phase screens are NOT Nav navigations - they are children of a
## persistent RoundRoot (consistency guide §8, Slice 3).


func _ready() -> void:
	# Slice 18: canvas_items/expand stretch scales the UI with the window;
	# below this floor, proportional scaling alone can't keep dense screens
	# (lobby, reveal grid) usable.
	get_window().min_size = GameConstants.WINDOW_MIN_SIZE


func goto(route: String) -> void:
	var err: Error = get_tree().change_scene_to_file(route)
	if err != OK:
		push_error("Nav.goto failed for '%s' (%s)" % [route, error_string(err)])
		return
	# change_scene_to_file completes deferred; the signal announces intent.
	EventBus.scene_changed.emit(route)
