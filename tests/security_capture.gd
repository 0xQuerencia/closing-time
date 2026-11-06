class_name SecurityCapture
extends Node
## Real-renderer evidence for M4: the CCTV desk and feeds, doors, the breaker panel, the blackout and Leon on camera.
## Run: godot --path . --resolution 1280x720 -- --capture-m4   (writes local/screenshots/m4/)
const OUT := "res://local/screenshots/m4"
var world: Node3D
var game: Gameplay
var sec: Security
var player: CharacterBody3D

func run(market: Node3D) -> void:
	world = market
	game = market.gameplay
	sec = game.security
	player = market.player
	DirAccess.make_dir_recursive_absolute(OUT)
	game.dialogue.time_scale_for_tests = 0.0
	for i in 40:
		await get_tree().process_frame
	await _powered_and_desk()
	await _doors()
	await _door_detail()
	await _breaker()
	await _blackout()
	await _leon_on_camera()
	print("M4 CAPTURE COMPLETE dir=", OUT)
	await world.finish_run(0)

func _stand(pos: Vector3, target: Vector3) -> void:
	player.global_position = pos
	var d := target - (pos + Vector3(0, 1.62, 0))
	player.rotation = Vector3(0, atan2(-d.x, -d.z), 0)
	player.camera.rotation = Vector3(atan2(d.y, Vector2(d.x, d.z).length()), 0, 0)
	for i in 5:
		await get_tree().physics_frame

func _shot(shot_name: String) -> void:
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [OUT, shot_name]
	print("M4 CAPTURE ", shot_name, " status=", image.save_png(path), " size=", image.get_size())

func _feed_shot(index: int, shot_name: String) -> void:
	var viewport: SubViewport = sec.cctv.feeds[index].viewport
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	var spread := _contrast(image)
	print("M4 CAPTURE ", shot_name, " status=", image.save_png("%s/%s.png" % [OUT, shot_name]), " size=", image.get_size(), " luma_range=", spread)

func _contrast(image: Image) -> float:
	var low := 1.0
	var high := 0.0
	for y in range(0, image.get_height(), 4):
		for x in range(0, image.get_width(), 4):
			var l := image.get_pixel(x, y).get_luminance()
			low = minf(low, l)
			high = maxf(high, l)
	return snappedf(high - low, 0.001)

func _wait_live() -> void:
	while not sec.cctv.is_live():
		await get_tree().process_frame

func _powered_and_desk() -> void:
	await _stand(Vector3(7.0, 0.0, -3.9), Vector3(7.9, 0.95, -5.3))
	await _shot("m4_01_office_crt_live")
	await _feed_shot(0, "m4_feed_shop_floor")
	await _feed_shot(1, "m4_feed_rear_hall")
	sec.cctv.select(0)
	sec.cctv.enter()
	sec.cctv.settle()
	await _shot("m4_02_cctv_shop_floor")
	sec.cctv.select(1)
	await _shot("m4_03_cctv_rear_hall")
	for i in 75:
		await get_tree().process_frame
	sec.cctv._toggle_playback()
	await _shot("m4_cctv_recent_tape")
	sec.cctv._scrub_tape(-1)
	await _shot("m4_cctv_tape_scrubbed")
	sec.cctv._toggle_playback()
	sec.cctv.leave()
	sec.cctv.settle()

func _doors() -> void:
	await _stand(Vector3(4.25, 0.0, 1.5), Vector3(4.25, 1.2, -6.0))
	await _shot("m4_04_rear_door_closed")
	sec.rear_door.snap(true)
	await _shot("m4_05_rear_door_open")
	sec.rear_door.snap(false)
	await _stand(Vector3(1.7, 0.0, 9.0), Vector3(1.7, 1.2, 6.0))
	await _shot("m4_06_front_doors_closed")
	sec.front_door.snap(true)
	await _shot("m4_07_front_doors_open")
	sec.front_door.snap(false)
	await _stand(Vector3(1.9, 0.0, 4.6), Vector3(1.69, 0.95, 6.0))
	await _shot("m4_08_front_doors_inside")

func _door_detail() -> void:
	sec.rear_door.snap(false)
	sec.office_door.snap(false)
	sec.front_door.snap(false)
	await _stand(Vector3(4.25, 0.0, -3.0), Vector3(4.25, 1.2, -6.0))
	await _shot("m4_door_rear_steel")
	await _stand(Vector3(3.75, 0.0, -4.3), Vector3(5.0, 1.1, -4.3))
	await _shot("m4_door_office_wood")
	await _stand(Vector3(1.7, 0.0, 7.4), Vector3(1.7, 1.1, 6.0))
	await _shot("m4_door_front_outside")

func _breaker() -> void:
	await _stand(Vector3(4.15, 0.0, 2.4), Vector3(4.8, 1.5, 2.8))
	await _shot("m4_09_breaker_closed")
	sec.breaker.cover.snap(true)
	await _stand(Vector3(4.15, 0.0, 2.3), Vector3(4.8, 1.55, 2.8))
	await _shot("m4_10_breaker_open")

func _blackout() -> void:
	await _stand(Vector3(-5.6, 0.0, 4.9), Vector3(-1.0, 1.1, 0.0))
	await _shot("m4_11_store_powered")
	sec.power.trip_all()
	for i in 10:
		await get_tree().process_frame
	await _shot("m4_12_store_blackout")
	sec.flashlight.set_on(true)
	await _shot("m4_13_blackout_phone_light")
	await _stand(Vector3(4.25, 0.0, 2.2), Vector3(4.25, 1.2, -6.0))
	await _shot("m4_14_blackout_rear_hall_light")
	sec.flashlight.set_on(false)
	await _shot("m4_15_blackout_rear_hall_dark")
	await _stand(Vector3(7.0, 0.0, -3.9), Vector3(7.9, 0.95, -5.3))
	await _shot("m4_16_office_crt_unpowered")
	sec.power.flip("main", true)
	await _stand(Vector3(-5.6, 0.0, 4.9), Vector3(-1.0, 1.1, 0.0))
	await _shot("m4_17_main_back_security_off")
	sec.power.flip("security", true)
	await _wait_live()

func _leon_on_camera() -> void:
	var leon := sec.spawn_intruder()
	await leon.enter_building()
	await _stand(Vector3(7.0, 0.0, -3.9), Vector3(7.9, 0.95, -5.3))
	sec.cctv.select(1)
	sec.cctv.enter()
	sec.cctv.settle()
	await _shot("m4_18_cctv_leon_inside_door")
	await _feed_shot(1, "m4_feed_leon_inside_door")
	var state := {"done": false}
	(func():
		await leon.walk_to_camera(Cctv.CAMS[1].pos - Vector3(0, 1.6, 0))
		state.done = true).call()
	for i in 150:
		await get_tree().process_frame
	await _shot("m4_19_cctv_leon_walking")
	while not state.done:
		await get_tree().process_frame
	await _shot("m4_20_cctv_leon_looking")
	sec.cctv.kill_feed(1)
	for i in 10:
		await get_tree().process_frame
	await _shot("m4_21_cctv_signal_lost")
	sec.cctv.leave()
	sec.cctv.settle()
	await leon.leave_building()
