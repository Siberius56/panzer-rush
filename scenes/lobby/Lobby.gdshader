shader_type canvas_item;
render_mode unshaded;

uniform sampler2D tile_texture : source_color, repeat_enable, filter_linear;

uniform vec2 rect_size_px = vec2(512.0, 512.0);
uniform vec2 tile_size_px = vec2(64.0, 64.0);

// Vitesse en pixels par seconde.
// Exemple : vec2(32.0, 0.0) = déplacement vers la droite.
uniform vec2 scroll_speed_px = vec2(32.0, 0.0);

uniform vec4 tint : source_color = vec4(1.0);
uniform float alpha : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 safe_tile_size = max(tile_size_px, vec2(1.0));
	vec2 tile_count = rect_size_px / safe_tile_size;

	vec2 scrolling_uv = (scroll_speed_px / safe_tile_size) * TIME;
	vec2 tiled_uv = fract(UV * tile_count + scrolling_uv);

	vec4 tex_color = texture(tile_texture, tiled_uv);

	COLOR = tex_color * tint;
	COLOR.a *= alpha;
}