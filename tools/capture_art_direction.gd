extends SceneTree
## Actual game assets, paused for repeatable lighting and material inspection.
func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var world := (load("res://scenes/world/market_root.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	world.gameplay.flow.hide_all()
	world.gameplay.hud.visible = false
	world.gameplay.phone_ui.visible = false
	world.player.enabled = false
	var customer = world.gameplay.spawn_customer()
	for i in 8:
		await process_frame
	paused = true
	if customer:
		customer.position = Vector3(-5.5, 0, 3.8)
		customer.rotation.y = PI
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1600, 900)
	viewport.world_3d = root.world_3d
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	root.disable_3d = true
	var finish = (load("res://scenes/world/retro_effects.gd") as Script).new()
	viewport.add_child(finish)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.fov = 65
	camera.current = true
	var out := "res://local/screenshots/art-direction"
	DirAccess.make_dir_recursive_absolute(out)
	for shot in [
		["01_customer_close",Vector3(-5.3,1.62,5.2),Vector3(-5.5,1.45,3.8)],
		["02_checkout",Vector3(-7.2,1.62,5.2),Vector3(-2.4,1.3,-2.2)],
		["03_front_windows",Vector3(-1.5,1.62,-1.6),Vector3(.6,1.4,6.4)],
		["04_weak_aisle",Vector3(-4.55,1.62,2.7),Vector3(-2,1.3,-1.0)],
		["05_ballast_sag",Vector3(-4.55,1.62,2.7),Vector3(-2,1.3,-1.0)]]:
		if shot[0] == "05_ballast_sag":
			var look = world.get_node("FearsLook")
			look._flicker_left = look.SAG_SECONDS * 0.5
			look._process(0.0)
		camera.position = shot[1]
		camera.look_at(shot[2])
		for i in 12:
			await process_frame
		await RenderingServer.frame_post_draw
		print("ART CAPTURE ",shot[0]," result=",viewport.get_texture().get_image().save_png(out+"/"+shot[0]+".png"))
		if shot[0] == "02_checkout":
			finish.analog_enabled = false
			finish._sync_toggles()
			await process_frame
			await RenderingServer.frame_post_draw
			viewport.get_texture().get_image().save_png(out+"/02_checkout_clean.png")
			finish.analog_enabled = true
			finish._sync_toggles()
	print("ART CAPTURE COMPLETE ",Engine.get_version_info().string," ",RenderingServer.get_current_rendering_method())
	quit()
