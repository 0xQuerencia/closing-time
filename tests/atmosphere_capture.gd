class_name AtmosphereCapture
extends Node
## Real-renderer evidence for the grounded early-lot figure. Run with --capture-atmosphere.
const OUT := "res://local/screenshots/atmosphere"

func run(market: Node3D) -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	market.gameplay.director.delay_scale = 100.0
	market.gameplay.begin_shift()
	var cctv: Cctv = market.gameplay.security.cctv
	var player: CharacterBody3D = market.player
	player.global_position = Vector3(0.4, 0.0, 5.05)
	var camera: Camera3D = player.camera
	camera.look_at(Vector3(-2.5, 1.0, 12.3))
	await get_tree().create_timer(2.0).timeout
	await _save("lot_figure_waiting")
	await _save_feed(cctv, 2, "lot_cctv_live")
	await get_tree().create_timer(14.0).timeout
	await _save("lot_after_departure")
	print("ATMOSPHERE OPENING TAPE frames=", cctv._opening_tape[2].size())
	player.global_position = Vector3(7.0, 0.0, -3.9)
	camera.look_at(Vector3(7.9, 0.95, -5.3))
	cctv.select(2)
	cctv.enter()
	cctv.settle()
	cctv._toggle_playback()
	cctv.screen_material.set_shader_parameter("glitch", 0.0)
	cctv.screen_material.set_shader_parameter("tracking_amount", 0.0)
	cctv.set_process(false)
	print("ATMOSPHERE TAPE state powered=", cctv.grid.powered("security"), " feed_dead=", cctv.feeds[2].dead, " noise=", cctv.screen_material.get_shader_parameter("static_amount"))
	await get_tree().create_timer(0.5).timeout
	await _save("lot_early_cctv_tape")
	cctv._scrub_tape(cctv._playback_frames.size() - 1)
	await _save("lot_cctv_tape_scrubbed")
	cctv.leave()
	cctv.settle()
	market.gameplay.security.power.trip_all()
	market.gameplay.security.flashlight.set_on(true)
	player.global_position = Vector3(-2.39, 0.0, -2.9)
	camera.look_at(Vector3(-2.39, 1.4, -4.68))
	await get_tree().create_timer(9.0).timeout
	await _save("cooler_condensation_blackout")
	print("ATMOSPHERE CAPTURE COMPLETE dir=", OUT)
	await market.finish_run(0)

func _save_feed(cctv: Cctv, index: int, name: String) -> void:
	for i in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := (cctv.feeds[index].viewport as SubViewport).get_texture().get_image()
	print("ATMOSPHERE FEED ", name, " status=", image.save_png("%s/%s.png" % [OUT, name]))

func _save(name: String) -> void:
	for i in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	print("ATMOSPHERE CAPTURE ", name, " status=", image.save_png("%s/%s.png" % [OUT, name]))
