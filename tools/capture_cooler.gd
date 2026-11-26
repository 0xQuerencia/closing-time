extends SceneTree
## Paired captures of the production market using the real player camera and default exposure.

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var market = (load("res://scenes/world/market_root.tscn") as PackedScene).instantiate()
	root.add_child(market)
	var game: Gameplay = market.gameplay
	var progress := ChapterProgress.new()
	if not progress.load_content():
		quit(1)
		return
	for chapter in ["apartment", "route9"]:
		if progress.current_id() != chapter:
			quit(1)
			return
		for event in progress.chapters[progress.index].required:
			progress.record(event)
		progress.advance()
	game.persist_saves = false
	game.begin_production(progress.snapshot())
	market.player.enabled = false
	game.hud.visible = false
	game.phone_ui.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var prefix := "after"
	if "--before" in OS.get_cmdline_user_args():
		prefix = "before"
	var output := OS.get_environment("CLOSING_COOLER_CAPTURE_DIR")
	if output.is_empty():
		output = ProjectSettings.globalize_path("res://local/cooler")
	DirAccess.make_dir_recursive_absolute(output)
	paused = true
	var shots := [
		["aisle", Vector3(2.6, 1.62, -3.42), Vector3(-3.5, 1.20, -4.88), 82.0],
		["row-b", Vector3(-4.08, 1.62, -3.18), Vector3(-4.05, 1.36, -4.83), 75.0],
		["stock-card", Vector3(-5.81, 1.62, -3.56), Vector3(-5.9, 1.31, -4.55), 75.0],
	]
	var camera: Camera3D = market.player.camera
	for shot in shots:
		market.player.position = shot[1] - Vector3.UP * camera.position.y
		camera.look_at(shot[2])
		camera.fov = shot[3]
		for frame in range(5):
			await process_frame
		print("COOLER CAMERA ", shot[0], " eye=", camera.global_position, " aim=", shot[2], " fov=", camera.fov)
		if DisplayServer.get_name() == "headless":
			continue
		await RenderingServer.frame_post_draw
		var path := "%s/%s-%s.png" % [output, prefix, shot[0]]
		var result := root.get_texture().get_image().save_png(path)
		print("COOLER CAPTURE ", path, " size=", root.size, " scene_draws=",
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " error=", result)
		if result != OK:
			await market.finish_run(1)
			return
	await market.finish_run(0)
