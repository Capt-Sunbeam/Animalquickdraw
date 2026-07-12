class_name AvatarTextureCache
extends RefCounted
## Rasterize-once cache for avatar textures (Slice 11 §6). Key = SHA-256 of
## the serialized doc; value = circle-masked ImageTexture at the avatar
## resolution (chips downscale via TextureRect). Small LRU - max 8 players
## plus the house set. UI-side because it produces textures (cg §3: the
## simulation never touches pixels).

const CAPACITY: int = 16

static var _textures: Dictionary = {}       # key -> ImageTexture
static var _order: Array[String] = []       # LRU: oldest first


static func get_texture(doc: DrawingDoc) -> ImageTexture:
	if doc == null:
		return null
	var key: String = _key_for(doc)
	if _textures.has(key):
		_order.erase(key)
		_order.append(key)   # freshen
		return _textures[key]
	# Raster with the mask (fills can't leak outside the circle), then the
	# same equation zeroes the display alpha outside it.
	var img: Image = DocRasterizer.rasterize(doc, CircleMask.image())
	CircleMask.apply_display_alpha(img)
	var texture: ImageTexture = ImageTexture.create_from_image(img)
	_textures[key] = texture
	_order.append(key)
	while _order.size() > CAPACITY:
		_textures.erase(_order.pop_front())
	return texture


static func _key_for(doc: DrawingDoc) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(var_to_bytes(doc.to_dict()))
	return ctx.finish().hex_encode()
