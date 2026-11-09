extends SceneTree
## XDG_DATA_HOME=/tmp/closing-opt-visual godot --path . --always-on-top --script tools/capture_optimization.gd
const OUT := "res://local/screenshots/optimization"

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var market := (load("res://scenes/world/market_root.tscn") as PackedScene).instantiate()
	root.add_child(market)
	await process_frame
	var flow = market.gameplay.flow
	flow.persist_settings = false
	flow.settings.graphics_mode = "safe"
	flow.show_settings()
	var modes := ["performance", "balanced", "quality", "safe"]
	for expected_mode in modes:
		flow.press("graphics_mode")
		var preset: Dictionary = flow.GRAPHICS_PRESETS[expected_mode]
		assert(flow.settings.graphics_mode == expected_mode, "Graphics mode selection must persist in the menu")
		assert(is_equal_approx(root.scaling_3d_scale, float(preset.scale)), "Graphics mode must reach the real viewport")
		assert(root.msaa_3d == int(preset.msaa), "Graphics mode must apply MSAA")
		assert(root.positional_shadow_atlas_size == int(preset.shadow_atlas), "Graphics mode must apply shadow budget")
		await _save("settings_%s" % expected_mode)
	flow.settings.graphics_mode = "balanced"
	flow.apply_settings()
	flow.hide_all()
	market.player.enabled = false
	market.player.global_position = Vector3(-1.5, 0.05, 4.6)
	market.player.rotation = Vector3.ZERO
	market.player.camera.rotation = Vector3.ZERO
	await _save("store_native")
	var recorder = market.gameplay.security.cctv
	recorder.enter()
	recorder.settle()
	await _save("cctv")
	recorder.leave()
	recorder.settle()
	await create_timer(4.2).timeout
	for history in market.gameplay.security.cctv._history:
		assert(not history.is_empty(), "Every camera must still record background evidence")
	seed(4061)
	var previous: AudioStreamWAV
	var unique := {}
	for i in 40:
		var sound := Foley.take("step_tile")
		assert(sound != previous, "Consecutive footsteps must vary")
		assert(sound.get_length() > 0.04 and sound.get_length() < 0.5, "Footstep recording must import correctly")
		unique[sound.resource_path] = true
		previous = sound
	assert(unique.size() == 5, "All five recordings should be available")
	print("OPTIMIZATION CAPTURE COMPLETE; graphics presets and 40 footstep selections passed")
	await market.finish_run(0)

func _save(label: String) -> void:
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("%s/%s.png" % [OUT, label])
	assert(error == OK, "Screenshot save failed")
