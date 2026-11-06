extends Node3D
## Bounded rain, warm practical lighting and wet pavement. No extra shadow maps
## or screen-space reflection pass; rain never emits beneath the store roof.
func _ready() -> void:
	call_deferred("_dress")

func _dress() -> void:
	var world := get_parent()
	for node in world.find_children("*", "Light3D", false, false):
		var light := node as Light3D
		if light.is_in_group("store_lights") and light.position.x < 3.0:
			light.light_color = Color(1.0, 0.83, 0.61)
			light.light_specular = 0.55
			light.light_energy *= 1.3
	for node in world.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if str(mesh.name).begins_with("Fluorescent_diffuser") or str(mesh.name).begins_with("Fluorescent diffuser"):
			for surface in mesh.mesh.get_surface_count():
				var tube := mesh.get_active_material(surface) as StandardMaterial3D
				if tube:
					var warm := tube.duplicate() as StandardMaterial3D
					warm.emission = Color(1.0, 0.73, 0.4)
					warm.emission_energy_multiplier = 1.5
					mesh.set_surface_override_material(surface, warm)
		# The exterior is batched into one mesh. Match material surfaces, not
		# pre-export object names such as "Parking asphalt".
		if str(mesh.name).begins_with("exterior"):
			for surface in mesh.mesh.get_surface_count():
				var original := mesh.get_active_material(surface) as StandardMaterial3D
				if original and "asphalt" in original.resource_name.to_lower():
					var wet := original.duplicate() as StandardMaterial3D
					wet.roughness = 0.24
					wet.metallic_specular = 0.85
					mesh.set_surface_override_material(surface, wet)
					print("STOREFRONT: wet asphalt surface applied")
	_tune_forecourt(world)
	# A single cached cubemap supplies real store/sky reflections on wet surfaces.
	# It renders once at startup, without shadow rendering or per-frame recapture.
	var probe := ReflectionProbe.new()
	probe.name = "WetLotReflection"
	probe.position = Vector3(0, 1.8, 13)
	probe.size = Vector3(28, 9, 23)
	probe.max_distance = 32.0
	probe.box_projection = true
	probe.enable_shadows = false
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.intensity = 0.8
	add_child(probe)
	_build_rain()

func _tune_forecourt(world: Node) -> void:
	for node in world.find_children("*", "Light3D", false, false):
		var light := node as Light3D
		if absf(light.position.z - 7.0) < 0.1 and absf(light.position.y - 2.65) < 0.1:
			light.light_energy = 2.1 if light.position.x > 0.0 else 1.65
			light.light_color = Color(1.0, 0.82, 0.57)
			light.light_specular = 0.8
			if light is SpotLight3D:
				light.spot_range = 7.0
		if light.position.is_equal_approx(Vector3(-9, 5.1, 15)):
			light.light_energy = 3.4
			light.light_specular = 0.8
	# Painted metal drip edge adds a readable band to the existing canopy.
	var trim := MeshInstance3D.new()
	trim.name = "CanopyDripEdge"
	var strip := BoxMesh.new()
	strip.size = Vector3(18.7, 0.16, 0.065)
	trim.mesh = strip
	trim.position = Vector3(0, 3.3, 7.28)
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.32, 0.055, 0.035)
	paint.roughness = 0.6
	trim.material_override = paint
	trim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(trim)

func _build_rain() -> void:
	var rain := GPUParticles3D.new()
	rain.name = "ParkingRain"
	rain.amount = 1200
	rain.lifetime = 0.9
	rain.preprocess = 0.9
	rain.fixed_fps = 30
	rain.position = Vector3(0, 5.2, 17)
	rain.visibility_aabb = AABB(Vector3(-15, -6, -10), Vector3(30, 13, 20))
	rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var motion := ParticleProcessMaterial.new()
	motion.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	motion.emission_box_extents = Vector3(14, 3, 8)
	motion.direction = Vector3(-0.12, -1, 0.02)
	motion.spread = 2.0
	motion.initial_velocity_min = 8.0
	motion.initial_velocity_max = 11.0
	motion.gravity = Vector3(0, -3, 0)
	rain.process_material = motion
	var streak := QuadMesh.new()
	streak.size = Vector2(0.008, 0.19)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.48, 0.56, 0.62, 0.24)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.35
	material.emission_enabled = true
	material.emission = Color(0.12, 0.15, 0.18)
	material.emission_energy_multiplier = 0.25
	streak.material = material
	rain.draw_pass_1 = streak
	add_child(rain)
	print("RAIN BUDGET: 1200 particles, 30 Hz simulation, 1 draw pass, no shadows")
