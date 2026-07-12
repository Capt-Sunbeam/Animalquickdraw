class_name MenuWallpaper
extends TextureRect
## Slowly drifting, seamlessly looping collage of hand-drawn animals (art
## pass wallpaper). The drift is a UV scroll in a shader - moving the
## Control itself snaps to whole pixels and reads as jitter at slow
## speeds. The offset accumulates here and wraps to [0,1) so precision
## never degrades, then feeds the shader each frame.
## The tile texture is seamless by construction (compose_tile.py).

const DRIFT_PX_PER_SEC: Vector2 = Vector2(9.0, 6.0)
const INK_ALPHA: float = 0.4  # backdrop, not competition

var _offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	stretch_mode = TextureRect.STRETCH_TILE
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://ui/menu/menu_wallpaper.gdshader")
	mat.set_shader_parameter(&"ink_alpha", INK_ALPHA)
	material = mat


func _process(delta: float) -> void:
	if texture == null:
		return
	var tile: Vector2 = texture.get_size()
	_offset += DRIFT_PX_PER_SEC * delta / tile
	_offset = Vector2(fposmod(_offset.x, 1.0), fposmod(_offset.y, 1.0))
	(material as ShaderMaterial).set_shader_parameter(&"scroll", _offset)
