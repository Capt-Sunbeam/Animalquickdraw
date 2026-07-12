class_name DocRasterizer
extends RefCounted
## The single source of truth for pixels (Slice 1 §6). Every consumer - live
## canvas, replay, reveal grid, thumbnails/export, avatar chip - rasterizes
## through this class, so identical op lists are identical images everywhere.
##
## Determinism rules (binding, Slice 1 §6): CPU only, no anti-aliasing,
## integer/fixed-step math, hard-edged circle stamps, scanline flood fill
## with exact color match. GPU/SubViewport rendering is display-only.
## `mask` parameters are the Slice 11 circular-avatar hook; null = no mask.


static func new_canvas_image(size: Vector2i) -> Image:
	var img: Image = Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(Palette.CANVAS_BACKGROUND)
	return img


## Applies one op to img in place, deterministically.
static func apply_op(img: Image, op: DrawingOp, mask: Image = null) -> void:
	match op.type:
		DrawingOp.Type.STROKE:
			var stroke: Stroke = op
			stamp_stroke_range(img, stroke, 0, stroke.points.size() - 1, mask)
		DrawingOp.Type.FILL:
			var fill: FillOp = op
			_flood_fill(img, fill, mask)
		DrawingOp.Type.CLEAR:
			_clear(img, mask)
		DrawingOp.Type.TEXT:
			var text_op: TextOp = op
			_blit_text(img, text_op, mask)
		DrawingOp.Type.UNDO:
			# Slice 20: an undo is not paintable in isolation - it needs doc
			# context. Callers use rasterize()/rasterize_prefix() instead.
			push_error("DocRasterizer.apply_op: UndoOp has no standalone raster")


## Stamps a partial stroke segment (points[from_idx..to_idx] inclusive) -
## used for incremental live drawing and timed replay so partial rendering
## equals full rendering.
static func stamp_stroke_range(img: Image, stroke: Stroke, from_idx: int, to_idx: int, mask: Image = null) -> void:
	var count: int = stroke.points.size()
	if count == 0:
		return
	from_idx = clampi(from_idx, 0, count - 1)
	to_idx = clampi(to_idx, 0, count - 1)
	var radius: int = GameConstants.BRUSH_RADII_PX[stroke.size_index]
	var color: Color = Palette.COLORS[stroke.color_index]
	if from_idx == to_idx:
		_stamp_circle(img, stroke.points[from_idx], radius, color, mask)
		return
	for i: int in range(from_idx, to_idx):
		_stamp_segment(img, stroke.points[i], stroke.points[i + 1], radius, color, mask)


## Full re-raster (undo, initial display of a received doc, golden tests).
## Slice 20: reads the EFFECTIVE ops - undone work never paints the final.
static func rasterize(doc: DrawingDoc, mask: Image = null) -> Image:
	var img: Image = new_canvas_image(doc.canvas_size())
	for op: DrawingOp in doc.effective_ops():
		apply_op(img, op, mask)
	return img


## Effective-state raster of the first `count` RAW ops - the replay revert
## primitive (Slice 20): called when the playhead crosses an UndoOp, with
## count = that op's index + 1, so the marker cancels inside the prefix.
static func rasterize_prefix(doc: DrawingDoc, count: int, mask: Image = null) -> Image:
	var img: Image = new_canvas_image(doc.canvas_size())
	for op: DrawingOp in DrawingDoc.resolve_effective(doc.ops.slice(0, count)):
		apply_op(img, op, mask)
	return img


## SHA-256 hex of raw pixel bytes - the golden-test primitive.
static func image_hash(img: Image) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(img.get_data())
	return ctx.finish().hex_encode()


## Between consecutive points, stamp at fixed steps of 1.0 px along the
## segment (inclusive of both ends), computed with the same rounding
## everywhere (determinism rule 2).
static func _stamp_segment(img: Image, a: Vector2, b: Vector2, radius: int, color: Color, mask: Image) -> void:
	var steps: int = ceili(a.distance_to(b))
	if steps <= 0:
		_stamp_circle(img, a, radius, color, mask)
		return
	for s: int in steps + 1:
		_stamp_circle(img, a.lerp(b, float(s) / float(steps)), radius, color, mask)


## Filled hard-edged circle: per-pixel dx*dx + dy*dy <= r*r, no AA
## (determinism rule 1). Row spans let us use fill_rect (native, clipped)
## instead of per-pixel writes; |dx| <= floor(sqrt(r^2 - dy^2)) is exactly
## the per-pixel test for integer dx.
static func _stamp_circle(img: Image, center: Vector2, radius: int, color: Color, mask: Image) -> void:
	var cx: int = roundi(center.x)
	var cy: int = roundi(center.y)
	var r2: int = radius * radius
	var height: int = img.get_height()
	var width: int = img.get_width()
	for dy: int in range(-radius, radius + 1):
		var py: int = cy + dy
		if py < 0 or py >= height:
			continue
		var span: int = floori(sqrt(float(r2 - dy * dy)))
		if mask == null:
			img.fill_rect(Rect2i(cx - span, py, 2 * span + 1, 1), color)
		else:
			for px: int in range(maxi(cx - span, 0), mini(cx + span + 1, width)):
				if mask.get_pixel(px, py).a >= 0.5:
					img.set_pixel(px, py, color)


## Hard-edged glyph blit (Slice 16 §6): PixelFont rows scaled by an integer
## factor, runs of consecutive set bits become fill_rect spans (native,
## clipped) - the text analogue of the circle-stamp row spans. Integer math
## only, no AA (determinism rules 1-2). Masked path is per-pixel (Slice 11).
static func _blit_text(img: Image, op: TextOp, mask: Image) -> void:
	var scale: int = GameConstants.TEXT_SCALES[op.size_index]
	var color: Color = Palette.COLORS[op.color_index]
	var advance: int = GameConstants.TEXT_GLYPH_PX * scale
	var pen_x: int = op.x
	for i: int in op.text.length():
		var rows: PackedByteArray = PixelFont.glyph_rows(op.text.unicode_at(i))
		if rows.is_empty():
			pen_x += advance  # unsupported char (parser prevents; defensive)
			continue
		for row: int in PixelFont.ROWS_PER_GLYPH:
			var bits: int = rows[row]
			if bits == 0:
				continue
			var py: int = op.y + row * scale
			var col: int = 0
			while col < GameConstants.TEXT_GLYPH_PX:
				if bits & (1 << col) == 0:
					col += 1
					continue
				var run: int = 1
				while col + run < GameConstants.TEXT_GLYPH_PX and bits & (1 << (col + run)) != 0:
					run += 1
				var rect := Rect2i(pen_x + col * scale, py, run * scale, scale)
				if mask == null:
					img.fill_rect(rect, color)
				else:
					_fill_rect_masked(img, rect, color, mask)
				col += run
		pen_x += advance


## Per-pixel masked variant of fill_rect (clips to the image first).
static func _fill_rect_masked(img: Image, rect: Rect2i, color: Color, mask: Image) -> void:
	var clipped: Rect2i = rect.intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	for py: int in range(clipped.position.y, clipped.end.y):
		for px: int in range(clipped.position.x, clipped.end.x):
			if mask.get_pixel(px, py).a >= 0.5:
				img.set_pixel(px, py, color)


static func _clear(img: Image, mask: Image) -> void:
	if mask == null:
		img.fill(Palette.CANVAS_BACKGROUND)
		return
	for y: int in img.get_height():
		for x: int in img.get_width():
			if mask.get_pixel(x, y).a >= 0.5:
				img.set_pixel(x, y, Palette.CANVAS_BACKGROUND)


## Scanline flood fill, 4-connected, exact RGBA match at seed (determinism
## rule 3). Runs on a PackedInt32Array view of the pixel bytes so the whole
## fill costs two Image data copies instead of per-pixel native calls.
## Outside-mask pixels are treated as boundary (Slice 11 hook).
static func _flood_fill(img: Image, fill: FillOp, mask: Image) -> void:
	var width: int = img.get_width()
	var height: int = img.get_height()
	if fill.x < 0 or fill.x >= width or fill.y < 0 or fill.y >= height:
		return  # validated upstream; a hostile op is a silent no-op
	if mask != null and mask.get_pixel(fill.x, fill.y).a < 0.5:
		return
	var px: PackedInt32Array = img.get_data().to_int32_array()
	var fill_color: Color = Palette.COLORS[fill.color_index]
	var fill32: int = _color_to_le32(fill_color)
	var target: int = px[fill.y * width + fill.x]
	if target == fill32:
		return  # same-color fill: visual no-op (the op itself is still recorded)
	var blocked: PackedByteArray = _mask_blocked(mask, width, height)
	var stack: Array[Vector2i] = [Vector2i(fill.x, fill.y)]
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		var row: int = p.y * width
		if px[row + p.x] != target:
			continue
		var x0: int = p.x
		while x0 - 1 >= 0 and px[row + x0 - 1] == target and blocked[row + x0 - 1] == 0:
			x0 -= 1
		var x1: int = p.x
		while x1 + 1 < width and px[row + x1 + 1] == target and blocked[row + x1 + 1] == 0:
			x1 += 1
		for x: int in range(x0, x1 + 1):
			px[row + x] = fill32
		for ny: int in [p.y - 1, p.y + 1]:
			if ny < 0 or ny >= height:
				continue
			var nrow: int = ny * width
			var x: int = x0
			while x <= x1:
				if px[nrow + x] == target and blocked[nrow + x] == 0:
					stack.push_back(Vector2i(x, ny))
					while x <= x1 and px[nrow + x] == target and blocked[nrow + x] == 0:
						x += 1
				else:
					x += 1
	img.set_data(width, height, false, Image.FORMAT_RGBA8, px.to_byte_array())


## RGBA8 bytes as a little-endian int32 (R lowest byte) - matches the memory
## layout produced by to_int32_array() on every target platform (all LE).
static func _color_to_le32(color: Color) -> int:
	var r: int = int(roundf(color.r * 255.0))
	var g: int = int(roundf(color.g * 255.0))
	var b: int = int(roundf(color.b * 255.0))
	var a: int = int(roundf(color.a * 255.0))
	var packed: int = r | (g << 8) | (b << 16) | (a << 24)
	# Keep the value in signed-int32 range the way to_int32_array() reads it.
	if packed >= 0x80000000:
		packed -= 0x100000000
	return packed


## 1 byte per pixel: 1 = blocked (outside mask), 0 = paintable.
static func _mask_blocked(mask: Image, width: int, height: int) -> PackedByteArray:
	var blocked: PackedByteArray = PackedByteArray()
	blocked.resize(width * height)  # zero-initialized
	if mask == null:
		return blocked
	for y: int in height:
		for x: int in width:
			if mask.get_pixel(x, y).a < 0.5:
				blocked[y * width + x] = 1
	return blocked
