shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never, blend_mix;

uniform vec4 shadow_color : source_color = vec4(0.42, 0.48, 0.65, 0.28);
uniform float inner_radius : hint_range(0.0, 1.0) = 0.05;
uniform float outer_radius : hint_range(0.1, 1.5) = 1.0;

void fragment() {
	vec2 centered_uv = UV - vec2(0.5);
	float distance_from_center = length(centered_uv) * 2.0;
	float radial_alpha = 1.0 - smoothstep(inner_radius, outer_radius, distance_from_center);
	ALBEDO = shadow_color.rgb;
	ALPHA = radial_alpha * shadow_color.a;
}
