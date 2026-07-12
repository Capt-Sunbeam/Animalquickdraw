class_name PoolType
extends RefCounted
## One draw specification loaded from pool_types.json (Slice 3 TDD §2).
## Immutable after load. Fully data-driven per brief §8: a type declares
## which pools it draws from, how many from each, and how the drawn words
## compose - future types (hybrids, objects...) are new JSON entries, not
## code changes.

var id: String = ""
var display_name: String = ""
var draws: Array[Dictionary] = []   # [{"pool": String, "count": int}]
var template: String = ""           # positional over flattened draw results


static func from_dict(d: Dictionary) -> PoolType:
	var t := PoolType.new()
	t.id = str(d.get("id", ""))
	t.display_name = str(d.get("display_name", ""))
	t.template = str(d.get("template", ""))
	for raw: Variant in d.get("draws", []):
		if not raw is Dictionary:
			continue
		var raw_dict: Dictionary = raw
		t.draws.append({
			"pool": str(raw_dict.get("pool", "")),
			"count": int(raw_dict.get("count", 0)),
		})
	return t


func total_draw_count() -> int:
	var n: int = 0
	for d: Dictionary in draws:
		n += int(d["count"])
	return n


## "{0} {1}" over the flattened parts in declared draw order.
func apply_template(parts: PackedStringArray) -> String:
	return template.format(Array(parts))
