class_name PhaseTimer
extends Label
## Shared countdown widget (Slice 3 TDD §7). Renders purely locally against
## the host-broadcast unix-ms deadline - no per-tick sync. Clamped to zero;
## urgency under 10 s shows color AND the number itself (never color alone,
## cg §13). Reused by every phase screen and Slice 7's force-continue.

const URGENT_SEC: int = 10
const URGENT_COLOR: Color = Color(1.0, 0.45, 0.35)

var _deadline_ms: int = 0
var _running: bool = false


func _ready() -> void:
	text = ""


func start(deadline_ms: int) -> void:
	_deadline_ms = deadline_ms
	_running = true
	_refresh()


func stop() -> void:
	_running = false
	text = ""


func remaining_sec() -> int:
	return ceili(maxi(0, _deadline_ms - _local_now_ms()) / 1000.0)


func _process(_delta: float) -> void:
	if _running:
		_refresh()


func _refresh() -> void:
	var sec: int = remaining_sec()
	@warning_ignore("integer_division")
	text = "%d:%02d" % [sec / 60, sec % 60]
	if sec <= URGENT_SEC:
		add_theme_color_override("font_color", URGENT_COLOR)
	else:
		remove_theme_color_override("font_color")


static func _local_now_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)
