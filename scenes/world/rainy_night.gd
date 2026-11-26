extends Node3D
## Bounded rain. Streaks never emit beneath the store roof.
func _ready() -> void:
	_build_rain()

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
