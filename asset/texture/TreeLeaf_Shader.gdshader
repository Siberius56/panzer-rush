shader_type spatial;

render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 leaf_color : source_color = vec4(0.08, 0.35, 0.32, 1.0);

uniform float wind_strength : hint_range(0.0, 1.0) = 0.18;
uniform float wind_speed : hint_range(0.0, 5.0) = 1.4;
uniform float wind_scale : hint_range(0.1, 10.0) = 1.8;

uniform float gust_strength : hint_range(0.0, 1.0) = 0.08;
uniform float gust_speed : hint_range(0.0, 5.0) = 0.6;
uniform float gust_scale : hint_range(0.1, 20.0) = 4.0;

uniform vec2 wind_direction = vec2(1.0, 0.0);

uniform float vertical_flutter : hint_range(0.0, 1.0) = 0.04;
uniform float height_influence : hint_range(0.0, 3.0) = 1.3;

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	vec2 dir = normalize(wind_direction);

	// Phase basée sur la position monde.
	// Important : tous les arbres partagent le même vent spatial.
	float wind_phase = dot(world_pos.xz, dir) * wind_scale + TIME * wind_speed;

	// Rafale plus lente, pour éviter un mouvement trop mécanique.
	float gust_phase = dot(world_pos.xz, dir) * gust_scale + TIME * gust_speed;

	float main_wave = sin(wind_phase);
	float secondary_wave = sin(wind_phase * 2.17 + world_pos.x * 0.35);
	float gust_wave = sin(gust_phase) * 0.5 + 0.5;

	// Plus le vertex est haut, plus il bouge.
	// À ajuster selon ton modèle.
	float height_mask = clamp(VERTEX.y * height_influence, 0.0, 1.0);

	float wind_amount = main_wave * wind_strength;
	wind_amount += secondary_wave * wind_strength * 0.35;
	wind_amount += gust_wave * gust_strength;

	wind_amount *= height_mask;

	vec3 world_offset = vec3(
		dir.x * wind_amount,
		sin(wind_phase * 1.6) * vertical_flutter * height_mask,
		dir.y * wind_amount
	);

	world_pos += world_offset;

	VERTEX = (inverse(MODEL_MATRIX) * vec4(world_pos, 1.0)).xyz;
}

void fragment() {
	ALBEDO = leaf_color.rgb;
	ROUGHNESS = 0.85;
	SPECULAR = 0.15;
}