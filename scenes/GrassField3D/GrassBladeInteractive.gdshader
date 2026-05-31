shader_type spatial;

render_mode cull_disabled, diffuse_lambert, specular_disabled;

uniform vec4 bottom_color : source_color = vec4(0.12, 0.30, 0.08, 1.0);
uniform vec4 top_color : source_color = vec4(0.46, 0.72, 0.22, 1.0);

uniform float wind_strength = 0.12;
uniform float wind_speed = 1.25;
uniform float wind_frequency = 1.80;
uniform vec2 wind_direction = vec2(1.0, 0.35);

uniform float vertical_push = 0.35;
uniform float bend_response = 1.0;

uniform vec4 interactor_0 = vec4(99999.0, 0.0, 99999.0, 0.0);
uniform vec4 interactor_1 = vec4(99999.0, 0.0, 99999.0, 0.0);
uniform vec4 interactor_2 = vec4(99999.0, 0.0, 99999.0, 0.0);
uniform vec4 interactor_3 = vec4(99999.0, 0.0, 99999.0, 0.0);
uniform vec4 interactor_4 = vec4(99999.0, 0.0, 99999.0, 0.0);
uniform vec4 interactor_5 = vec4(99999.0, 0.0, 99999.0, 0.0);
uniform vec4 interactor_6 = vec4(99999.0, 0.0, 99999.0, 0.0);
uniform vec4 interactor_7 = vec4(99999.0, 0.0, 99999.0, 0.0);

uniform float interactor_strength_0 = 0.0;
uniform float interactor_strength_1 = 0.0;
uniform float interactor_strength_2 = 0.0;
uniform float interactor_strength_3 = 0.0;
uniform float interactor_strength_4 = 0.0;
uniform float interactor_strength_5 = 0.0;
uniform float interactor_strength_6 = 0.0;
uniform float interactor_strength_7 = 0.0;

varying float v_height_factor;
varying float v_color_variation;

vec3 get_bend_offset(vec3 world_pos, vec4 interactor, float strength, float height_factor) {
	if (interactor.w <= 0.001 || strength <= 0.001) {
		return vec3(0.0);
	}

	vec2 interactor_xz = interactor.xz;
	float radius = interactor.w;
	vec2 away_dir = world_pos.xz - interactor_xz;
	float dist = length(away_dir);

	if (dist < 0.001) {
		away_dir = vec2(1.0, 0.0);
	} else {
		away_dir /= dist;
	}

	float influence = smoothstep(radius, 0.0, dist);
	float top_weight = height_factor * height_factor;
	float bend_amount = influence * strength * bend_response * top_weight;

	return vec3(
		away_dir.x * bend_amount,
		-bend_amount * vertical_push,
		away_dir.y * bend_amount
	);
}

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	float height_factor = clamp(UV.y, 0.0, 1.0);
	float top_weight = height_factor * height_factor;

	float phase_offset = INSTANCE_CUSTOM.r * 6.28318530718;
	v_color_variation = INSTANCE_CUSTOM.g;
	float bend_variation = mix(0.85, 1.20, INSTANCE_CUSTOM.b);

	vec2 safe_wind_direction = wind_direction;
	if (length(safe_wind_direction) < 0.001) {
		safe_wind_direction = vec2(1.0, 0.0);
	}

	vec2 normalized_wind_direction = normalize(safe_wind_direction);
	float phase = dot(world_pos.xz, normalized_wind_direction) * wind_frequency + TIME * wind_speed + phase_offset;
	float wave = sin(phase) + sin(phase * 0.47 + 1.7) * 0.35;

	vec3 wind_offset = vec3(
		normalized_wind_direction.x,
		0.0,
		normalized_wind_direction.y
	) * wave * wind_strength * top_weight * bend_variation;

	vec3 interaction_offset = vec3(0.0);
	interaction_offset += get_bend_offset(world_pos, interactor_0, interactor_strength_0, height_factor);
	interaction_offset += get_bend_offset(world_pos, interactor_1, interactor_strength_1, height_factor);
	interaction_offset += get_bend_offset(world_pos, interactor_2, interactor_strength_2, height_factor);
	interaction_offset += get_bend_offset(world_pos, interactor_3, interactor_strength_3, height_factor);
	interaction_offset += get_bend_offset(world_pos, interactor_4, interactor_strength_4, height_factor);
	interaction_offset += get_bend_offset(world_pos, interactor_5, interactor_strength_5, height_factor);
	interaction_offset += get_bend_offset(world_pos, interactor_6, interactor_strength_6, height_factor);
	interaction_offset += get_bend_offset(world_pos, interactor_7, interactor_strength_7, height_factor);

	world_pos += wind_offset + interaction_offset;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(world_pos, 1.0)).xyz;

	v_height_factor = height_factor;
}

void fragment() {
	vec3 color = mix(bottom_color.rgb, top_color.rgb, v_height_factor);
	float color_multiplier = mix(0.85, 1.15, v_color_variation);
	ALBEDO = color * color_multiplier;
	ROUGHNESS = 1.0;
}
