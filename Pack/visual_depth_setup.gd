@tool
extends Node3D

## Preset visuel topdown coloré.
## Dépose cette scène dans ton niveau, puis copie tes assets sous AssetAnchors.
## Godot 4.x.

enum VisualPreset {
	SUNNY_TOYBOX,
	PASTEL_ADVENTURE,
	WARM_AFTERNOON
}

@export var preset: VisualPreset = VisualPreset.PASTEL_ADVENTURE
@export var apply_on_ready: bool = true

@export_group("Sun")
@export var sun_rotation_degrees: Vector3 = Vector3(-48.0, -35.0, 0.0)
@export var sun_color: Color = Color.html("#FFDFA0")
@export var sun_energy: float = 1.35
@export var sun_shadow_opacity: float = 0.52
@export var sun_shadow_blur: float = 2.5
@export var sun_angular_distance: float = 2.2
@export var shadow_max_distance: float = 80.0

@export_group("Ambient")
@export var ambient_color: Color = Color.html("#A6B8E8")
@export var ambient_energy: float = 0.48
@export var background_color: Color = Color.html("#BFE8FF")

@export_group("Fog")
@export var fog_enabled: bool = true
@export var fog_color: Color = Color.html("#D4E3FF")
@export var fog_density: float = 0.010
@export var fog_depth_begin: float = 28.0
@export var fog_depth_end: float = 105.0
@export var fog_aerial_perspective: float = 0.25

@export_group("Post Process")
@export var glow_enabled: bool = true
@export var glow_intensity: float = 0.18
@export var glow_strength: float = 0.55
@export var saturation: float = 1.08
@export var contrast: float = 1.03
@export var brightness: float = 1.02
@export var vignette_color: Color = Color.html("#D5DCFF")
@export var vignette_intensity: float = 0.08

@export_group("Fill Light")
@export var fill_light_enabled: bool = true
@export var fill_color: Color = Color.html("#C8D9FF")
@export var fill_energy: float = 0.22
@export var fill_rotation_degrees: Vector3 = Vector3(-40.0, 135.0, 0.0)

func _ready() -> void:
	if apply_on_ready:
		apply_preset_values()

func apply_preset_values() -> void:
	_apply_named_preset()
	_apply_sun()
	_apply_fill_light()
	_apply_environment()
	_apply_vignette()

func _apply_named_preset() -> void:
	if preset == VisualPreset.SUNNY_TOYBOX:
		sun_color = Color.html("#FFE7A8")
		sun_energy = 1.45
		ambient_color = Color.html("#B7C7F2")
		ambient_energy = 0.55
		fog_color = Color.html("#DCEEFF")
		fog_density = 0.006
		vignette_color = Color.html("#E3E8FF")
		vignette_intensity = 0.05
	elif preset == VisualPreset.PASTEL_ADVENTURE:
		sun_color = Color.html("#FFDFA0")
		sun_energy = 1.35
		ambient_color = Color.html("#A6B8E8")
		ambient_energy = 0.48
		fog_color = Color.html("#D4E3FF")
		fog_density = 0.010
		vignette_color = Color.html("#D5DCFF")
		vignette_intensity = 0.08
	elif preset == VisualPreset.WARM_AFTERNOON:
		sun_color = Color.html("#FFD18A")
		sun_energy = 1.25
		ambient_color = Color.html("#B6C8EC")
		ambient_energy = 0.52
		fog_color = Color.html("#E8F2FF")
		fog_density = 0.005
		vignette_color = Color.html("#F0E5FF")
		vignette_intensity = 0.06

func _apply_sun() -> void:
	var sun: DirectionalLight3D = get_node_or_null("Sun") as DirectionalLight3D
	if sun == null:
		return

	sun.rotation_degrees = sun_rotation_degrees
	sun.light_color = sun_color
	sun.light_energy = sun_energy
	sun.light_indirect_energy = 0.6
	sun.light_volumetric_fog_energy = 0.35
	sun.light_angular_distance = sun_angular_distance
	sun.shadow_enabled = true
	sun.shadow_opacity = sun_shadow_opacity
	sun.shadow_blur = sun_shadow_blur
	sun.shadow_bias = 0.06
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_fade_start = 0.72
	sun.directional_shadow_max_distance = shadow_max_distance
	sun.directional_shadow_split_1 = 0.08
	sun.directional_shadow_split_2 = 0.22
	sun.directional_shadow_split_3 = 0.48

func _apply_fill_light() -> void:
	var fill_light: DirectionalLight3D = get_node_or_null("SoftBlueFill") as DirectionalLight3D
	if fill_light == null:
		return

	fill_light.visible = fill_light_enabled
	fill_light.rotation_degrees = fill_rotation_degrees
	fill_light.light_color = fill_color
	fill_light.light_energy = fill_energy
	fill_light.light_indirect_energy = 0.2
	fill_light.light_volumetric_fog_energy = 0.0
	fill_light.shadow_enabled = false

func _apply_environment() -> void:
	var world_environment: WorldEnvironment = get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_environment == null:
		return

	var environment: Environment = world_environment.environment
	if environment == null:
		environment = Environment.new()
		world_environment.environment = environment

	environment.background_mode = Environment.BG_COLOR
	environment.background_color = background_color
	environment.background_energy_multiplier = 1.0

	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = ambient_color
	environment.ambient_light_energy = ambient_energy
	environment.ambient_light_sky_contribution = 0.0

	environment.fog_enabled = fog_enabled
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_light_color = fog_color
	environment.fog_light_energy = 0.65
	environment.fog_density = fog_density
	environment.fog_depth_begin = fog_depth_begin
	environment.fog_depth_end = fog_depth_end
	environment.fog_depth_curve = 1.25
	environment.fog_aerial_perspective = fog_aerial_perspective
	environment.fog_sky_affect = 0.15
	environment.fog_sun_scatter = 0.08

	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.02
	environment.tonemap_white = 1.15

	environment.adjustment_enabled = true
	environment.adjustment_brightness = brightness
	environment.adjustment_contrast = contrast
	environment.adjustment_saturation = saturation

	environment.glow_enabled = glow_enabled
	environment.glow_intensity = glow_intensity
	environment.glow_strength = glow_strength
	environment.glow_bloom = 0.02
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	environment.glow_hdr_threshold = 1.15
	environment.glow_hdr_scale = 1.2
	environment.set_glow_level(1, 0.0)
	environment.set_glow_level(2, 0.32)
	environment.set_glow_level(3, 0.16)
	environment.set_glow_level(4, 0.04)
	environment.set_glow_level(5, 0.0)
	environment.set_glow_level(6, 0.0)
	environment.set_glow_level(7, 0.0)

	environment.ssao_enabled = true
	environment.ssao_radius = 1.1
	environment.ssao_intensity = 0.65
	environment.ssao_power = 1.2
	environment.ssao_detail = 0.35

func _apply_vignette() -> void:
	var color_rect: ColorRect = get_node_or_null("PostProcess/VignetteOverlay") as ColorRect
	if color_rect == null:
		return

	var shader_material: ShaderMaterial = color_rect.material as ShaderMaterial
	if shader_material == null:
		return

	shader_material.set_shader_parameter("vignette_color", vignette_color)
	shader_material.set_shader_parameter("intensity", vignette_intensity)
	shader_material.set_shader_parameter("radius", 0.55)
	shader_material.set_shader_parameter("softness", 0.45)
