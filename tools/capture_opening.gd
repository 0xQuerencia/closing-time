extends SceneTree
## Regenerate startup art from the real game: godot --path . --script tools/capture_opening.gd
func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	root.size = Vector2i(1600, 900)
	var world := (load("res://scenes/world/market_root.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	world.gameplay.flow.hide_all()
	world.gameplay.hud.visible = false
	world.gameplay.phone_ui.visible = false
	world.player.enabled = false
	paused = true
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1600, 900)
	viewport.world_3d = root.world_3d
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	root.disable_3d = true
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.position = Vector3(-3.4, 1.7, 19.5)
	camera.look_at(Vector3(-0.5, 1.65, 6.0))
	camera.fov = 65
	camera.current = true
	for i in 90:
		await process_frame
	await RenderingServer.frame_post_draw
	var error := viewport.get_texture().get_image().save_png("res://assets/art/market_loading.png")
	print("OPENING GAME CAPTURE result=", error, " engine=", Engine.get_version_info().string, " renderer=", RenderingServer.get_current_rendering_method())
	quit(error)
