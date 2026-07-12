class_name Prompt
extends RefCounted
## One drawn prompt (Slice 3 TDD §2). parts follow the pool type's declared
## draw order, which makes combo_key deterministic for the no-repeat set.

var pool_type_id: String = ""
var parts: PackedStringArray = PackedStringArray()
var display_text: String = ""     # e.g. "sleepy aardvark"
var combo_key: String = ""        # pool_type_id + ":" + "|".join(parts)


static func make(type: PoolType, drawn_parts: PackedStringArray) -> Prompt:
	var p := Prompt.new()
	p.pool_type_id = type.id
	p.parts = drawn_parts
	p.display_text = type.apply_template(drawn_parts)
	p.combo_key = "%s:%s" % [type.id, "|".join(drawn_parts)]
	return p
