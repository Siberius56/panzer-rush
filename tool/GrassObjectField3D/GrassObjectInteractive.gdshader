shader_type spatial;

render_mode cull_disabled, diffuse_lambert, specular_disabled;

uniform vec4 bottom_color : source_color = vec4(0.12, 0.30, 0.08, 1.0);
uniform vec4 top_color : source_color = vec4(0.46, 0.72, 0.22, 1.0);
uniform bool use_albedo_texture = false;
uniform sampler2D albedo_texture : source_color;

uniform float mesh_base_y = 0.0;
uniform float mesh_height = 1.0;

uniform float wind_strength_degrees = 7.0;
uniform float wind_speed = 1.25;
uniform float wind_frequency = 1.80;
uniform vec2 wind_direction = vec2(1.0, 0.35);
uniform float wind_flattened_multiplier = 0.35;

uniform float max_bend_degrees = 78.0;
uniform float normal_up_blend = 0.95;
uniform float minimum_light = 0.75;
uniform float emission_strength = 0.08;
uniform float light_response = 0.15;
uniform float color_variation_strength = 0.04;
uniform vec4 ground_blend_color : source_color = vec4(0.16, 0.29, 0.09, 1.0);
uniform float ground_blend_strength = 0.25;

varying float v_height_factor;
varying float v_color_variation;

const float GRASS_TAU = 6.28318530718;

vec3 rotate_around_axis(vec3 value, vec3 axis, float angle) {
	float s = sin(angle);
	float c = cos(angle);
	return value * c + cross(axis, value) * s + axis * dot(axis, value) * (1.0 - c);
}

vec3 safe_horizontal_direction(vec2 direction_2d) {
	if (length(direction_2d) < 0.001) {
		return vec3(1.0, 0.0, 0.0);
	}

	vec2 normalized_direction = normalize(direction_2d);
	return vec3(normalized_direction.x, 0.0, normalized_direction.y);
}

vec3 bend_axis_from_direction(vec3 horizontal_direction) {
	vec3 axis = cross(vec3(0.0, 1.0, 0.0), horizontal_direction);
	if (length(axis) < 0.001) {
		return vec3(0.0, 0.0, -1.0);
	}

	return normalize(axis);
}

void vertex() {
	float safe_mesh_height = max(mesh_height, 0.001);
	float height_factor = clamp((VERTEX.y - mesh_base_y) / safe_mesh_height, 0.0, 1.0);
	v_height_factor = height_factor;
	v_color_variation = INSTANCE_CUSTOM.a;

	vec3 pivot_world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 relative = world_position - pivot_world;

	float bend_amount = clamp(INSTANCE_CUSTOM.b, 0.0, 1.0);
	float bend_angle_normalized = INSTANCE_CUSTOM.g;
	float bend_angle_radians = radians(max_bend_degrees) * bend_amount;
	float bend_direction_angle = bend_angle_normalized * GRASS_TAU;
	vec3 bend_direction = vec3(cos(bend_direction_angle), 0.0, sin(bend_direction_angle));
	vec3 bend_axis = bend_axis_from_direction(bend_direction);

	relative = rotate_around_axis(relative, bend_axis, bend_angle_radians);

	vec3 wind_dir = safe_horizontal_direction(wind_direction);
	float wind_phase = dot(pivot_world.xz, wind_dir.xz) * wind_frequency + TIME * wind_speed + INSTANCE_CUSTOM.r * GRASS_TAU;
	float wind_wave = sin(wind_phase) + sin(wind_phase * 0.47 + 1.7) * 0.35;
	float wind_availability = mix(1.0, wind_flattened_multiplier, bend_amount);
	float wind_angle = radians(wind_strength_degrees) * wind_wave * wind_availability;
	vec3 wind_axis = bend_axis_from_direction(wind_dir);

	relative = rotate_around_axis(relative, wind_axis, wind_angle);

	world_position = pivot_world + relative;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(world_position, 1.0)).xyz;
}

void fragment() {
	vec3 gradient_color = mix(bottom_color.rgb, top_color.rgb, v_height_factor);
	vec3 final_color = mix(gradient_color, ground_blend_color.rgb, ground_blend_strength);

	float color_variation = (v_color_variation - 0.5) * 2.0;
	final_color *= 1.0 + color_variation * color_variation_strength;

	if (use_albedo_texture) {
		vec4 texture_color = texture(albedo_texture, UV);
		final_color *= texture_color.rgb;
		ALPHA = texture_color.a;
	}

	ALBEDO = final_color;
	EMISSION = ALBEDO * emission_strength;
	ROUGHNESS = 1.0;

	vec3 corrected_normal = normalize(NORMAL);
	if (!FRONT_FACING) {
		corrected_normal = -corrected_normal;
	}

	// Herbe stylisée : les normales sont fortement remontées vers le haut.
	// Cela évite les côtés noirs ou brillants sur les meshes fins.
	corrected_normal = normalize(mix(corrected_normal, vec3(0.0, 1.0, 0.0), normal_up_blend));
	NORMAL = corrected_normal;
}

void light() {
	vec3 corrected_normal = normalize(NORMAL);
	float ndotl = max(dot(corrected_normal, LIGHT), 0.0);
	float light_amount = mix(1.0, max(ndotl, minimum_light), light_response);
	float softened_attenuation = mix(1.0, ATTENUATION, light_response);

	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * softened_attenuation * light_amount;
}
