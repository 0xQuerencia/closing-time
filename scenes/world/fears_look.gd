class_name FearsLook
extends Node
## Dim, dirty, uneasy: cold fog, lower fill light, grime on every surface and one failing tube.
const GRIME_STRENGTH := 0.5
var _flicker_light: Light3D
var _flicker_base := 1.0
var _flicker_left := 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	name = "FearsLook"
	_rng.seed = 77
	var world := get_parent()
	_grade_environment(world)
	_dim_lights(world)
	_add_grime(world)

func _grade_environment(world: Node) -> void:
	for node in world.find_children("*", "WorldEnvironment", false, false):
		var env := (node as WorldEnvironment).environment
		if env == null:
			continue
		env.ambient_light_energy *= 0.70
		env.fog_enabled = true
		env.fog_light_color = Color(0.05, 0.065, 0.08)
		env.fog_density = 0.009
		env.fog_sky_affect = 0.0
		env.adjustment_enabled = true
		env.adjustment_contrast = 1.05
		env.adjustment_saturation = 0.92

func _dim_lights(world: Node) -> void:
	var tubes: Array[Light3D] = []
	for node in world.find_children("*", "Light3D", false, false):
		var light := node as Light3D
		if light.position.y > 2.0 and light.position.y < 3.0:
			light.light_energy *= 0.84
			light.light_color = light.light_color.lerp(Color(0.86, 0.95, 0.9), 0.35)
			tubes.append(light)
	if not tubes.is_empty():
		_flicker_light = tubes[tubes.size() / 2]
		_flicker_base = _flicker_light.light_energy

func _process(delta: float) -> void:
	if _flicker_light == null:
		return
	_flicker_left -= delta
	if _flicker_left > 0.0:
		_flicker_light.light_energy = _flicker_base * (0.15 if _rng.randf() < 0.55 else 0.85)
	else:
		_flicker_light.light_energy = _flicker_base
		if _rng.randf() < delta / 14.0:  # roughly one stutter every 14 s
			_flicker_left = _rng.randf_range(0.12, 0.45)

func _add_grime(world: Node) -> void:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.0045
	noise.fractal_octaves = 4
	var texture := NoiseTexture2D.new()
	texture.noise = noise
	texture.width = 512
	texture.height = 512
	texture.seamless = true
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(0.74, 0.72, 0.68), Color(1, 1, 1)])
	texture.color_ramp = ramp
	var cache := {}
	for node in world.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or mi.get_parent() is Customer or mi.name.begins_with("Product"):
			continue
		for surface in mi.mesh.get_surface_count():
			var base := mi.get_surface_override_material(surface)
			if base == null:
				base = mi.mesh.surface_get_material(surface)
			if not base is StandardMaterial3D:
				continue
			var key := base.get_instance_id()
			if not cache.has(key):
				var dirty := (base as StandardMaterial3D).duplicate() as StandardMaterial3D
				if dirty.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and not dirty.emission_enabled:
					dirty.detail_enabled = true
					dirty.detail_albedo = texture
					dirty.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
					dirty.albedo_color = dirty.albedo_color.lerp(Color(dirty.albedo_color.get_luminance(), dirty.albedo_color.get_luminance(), dirty.albedo_color.get_luminance()), 0.18)
					dirty.roughness = minf(1.0, dirty.roughness + 0.12)
				cache[key] = dirty
			mi.set_surface_override_material(surface, cache[key])
