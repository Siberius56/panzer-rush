shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform vec4 vignette_color : source_color = vec4(0.835, 0.862, 1.0, 1.0);
uniform float intensity : hint_range(0.0, 0.5) = 0.08;
uniform float radius : hint_range(0.0, 1.2) = 0.55;
uniform float softness : hint_range(0.05, 1.0) = 0.45;

void fragment() {
	vec2 centered_uv = SCREEN_UV - vec2(0.5);
	float distance_from_center = length(centered_uv) * 1.42;
	float vignette_mask = smoothstep(radius, radius + softness, distance_from_center);
	COLOR = vec4(vignette_color.rgb, vignette_mask * intensity);
}
