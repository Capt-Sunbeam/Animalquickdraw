shader_type canvas_item;

// Wallpaper drift: the control never moves (Control positions snap to
// whole pixels, which reads as jitter at slow speeds) - the texture UVs
// scroll instead, sub-pixel smooth on the GPU. `scroll` is wrapped to
// [0,1) script-side so precision never degrades on long menu idles.
//
// NOTE: fragment COLOR arrives ALREADY multiplied by the texture sampled
// at the unscrolled UV, so it must be fully overwritten here - multiplying
// leaves only pixels where the two samples overlap. Ink strength therefore
// comes in as a uniform instead of self_modulate.
uniform vec2 scroll = vec2(0.0);
uniform float ink_alpha = 0.4;

void fragment() {
	vec4 ink = texture(TEXTURE, UV + scroll);
	COLOR = vec4(ink.rgb, ink.a * ink_alpha);
}
