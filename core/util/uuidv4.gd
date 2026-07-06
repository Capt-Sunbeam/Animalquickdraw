class_name UuidV4
## RFC 4122 version-4 UUID generator (skeleton guide util). Used for the dev
## platform_id (skeleton), drawing_id minting (Slice 3), and collection item
## ids (Slice 4).

static var _rng: RandomNumberGenerator = _make_rng()


static func _make_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng


static func generate() -> String:
	var b: PackedByteArray = PackedByteArray()
	b.resize(16)
	for i: int in 16:
		b[i] = _rng.randi_range(0, 255)
	b[6] = (b[6] & 0x0F) | 0x40  # version 4
	b[8] = (b[8] & 0x3F) | 0x80  # RFC 4122 variant
	var hex: String = b.hex_encode()
	return "%s-%s-%s-%s-%s" % [
		hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4),
		hex.substr(16, 4), hex.substr(20, 12),
	]
