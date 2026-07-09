class_name CircleMask
extends RefCounted
## The canonical 512x512 circular avatar mask (Slice 11 §6): pixel inside iff
## (x - 255.5)^2 + (y - 255.5)^2 <= 256^2 - ONE equation drives stamping,
## fill boundary, input clamping, and display alpha, so every surface agrees
## on the exact same disc. Precomputed once per run; deterministic (integer
## pixel centers against fixed float constants, no AA).

const CENTER: Vector2 = Vector2(255.5, 255.5)
const RADIUS: float = 256.0

static var _cached: Image = null


## The mask image DocRasterizer consumes (alpha 1 inside, 0 outside).
static func image() -> Image:
	if _cached == null:
		var size: Vector2i = GameConstants.CANVAS_AVATAR
		_cached = Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
		var r2: float = RADIUS * RADIUS
		for y: int in size.y:
			var dy: float = float(y) - CENTER.y
			for x: int in size.x:
				var dx: float = float(x) - CENTER.x
				if dx * dx + dy * dy <= r2:
					_cached.set_pixel(x, y, Color(1, 1, 1, 1))
	return _cached


## Same equation as the mask image, for input decisions (fill clicks).
static func contains(p: Vector2) -> bool:
	return (p - CENTER).length_squared() <= RADIUS * RADIUS


## Nearest in-circle point - stroking outside clamps to the rim (§6 input
## rule) so the cursor never "loses" the stroke at the edge.
static func clamp_to_circle(p: Vector2) -> Vector2:
	var offset: Vector2 = p - CENTER
	if offset.length_squared() <= RADIUS * RADIUS:
		return p
	return CENTER + offset.normalized() * (RADIUS - 0.5)


## Display-only: zero the alpha outside the circle so the corners read as
## "not canvas". Applied AFTER authoritative rasterization - golden hashes
## are taken on the unmodified raster.
static func apply_display_alpha(img: Image) -> void:
	var mask: Image = image()
	for y: int in img.get_height():
		for x: int in img.get_width():
			if mask.get_pixel(x, y).a < 0.5:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
