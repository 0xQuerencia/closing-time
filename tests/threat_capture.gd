class_name ThreatCapture
extends Node
## Real-renderer evidence for M5: title, Leon in the shop, hiding, the office door and the three ending cards.
## Run: godot --path . --resolution 1280x720 -- --capture-m5   (writes local/screenshots/m5/)
const OUT := "res://local/screenshots/m5"
var world: Node3D
var game: Gameplay
var sec: Security
var player: CharacterBody3D
var threat: ThreatBeats

func run(market: Node3D) -> void:
	world = market
	game = market.gameplay
	sec = game.security
	player = market.player
	threat = game.director.threat
	DirAccess.make_dir_recursive_absolute(OUT)
	game.dialogue.time_scale_for_tests = 0.0
	for i in 40:
		await get_tree().process_frame
	game.flow.show_title()
	await _shot("m5_01_title")
	game.flow.hide_all()
	await _setup_climax()
	await _office_door()
	await _leon_in_hall()
	await _leon_in_shop()
	await _hiding()
	await _endings()
	print("M5 CAPTURE COMPLETE dir=", OUT)
	await world.finish_run(0)

func _shot(shot_name: String) -> void:
	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	print("M5 CAPTURE ", shot_name, " status=", image.save_png("%s/%s.png" % [OUT, shot_name]), " size=", image.get_size())

func _stand(pos: Vector3, target: Vector3) -> void:
	player.enabled = false
	player.global_position = pos
	var d := target - (pos + Vector3(0, 1.62, 0))
	player.rotation = Vector3(0, atan2(-d.x, -d.z), 0)
	player.camera.rotation = Vector3(atan2(d.y, Vector2(d.x, d.z).length()), 0, 0)
	for i in 4:
		await get_tree().physics_frame

func _setup_climax() -> void:
	game.director.flags = {"m4_complete": true, "rear_cam_lost": true}
	game.director.step = StoryDirector.Step.SECURITY_DONE
	game.clues.activate()
	threat.entry_delay = 0.2
	threat.police_eta = 6.0

func _office_door() -> void:
	await _stand(Vector3(3.6, 0.0, -4.3), Vector3(5.0, 1.2, -4.3))
	sec.office_door.set_locked(false, true)
	await _shot("m5_02_office_door_closed_from_hall")
	sec.office_door.snap(true)
	await _stand(Vector3(3.6, 0.0, -4.3), Vector3(6.5, 1.0, -4.3))
	await _shot("m5_03_office_door_open")
	sec.office_door.snap(false)
	await _stand(Vector3(6.2, 0.0, -4.6), Vector3(5.0, 1.0, -4.3))
	await _shot("m5_04_office_door_inside_bolt")

func _leon_in_hall() -> void:
	threat.begin()
	while not (is_instance_valid(threat.stalker) and threat.stalker.inside):
		await get_tree().physics_frame
	var leon := threat.stalker
	leon.stand_down()
	leon.global_position = Vector3(4.2, 0.0, -2.0)
	leon.rotation.y = PI
	await _stand(Vector3(4.25, 0.0, 3.4), Vector3(4.25, 1.4, -2.0))
	await _shot("m5_05_leon_in_rear_hall")

func _leon_in_shop() -> void:
	var leon := threat.stalker
	leon.global_position = Vector3(1.4, 0.0, 2.9)
	leon.rotation.y = atan2(1.0, 0.0)
	await _stand(Vector3(-4.0, 0.0, 3.6), Vector3(0.0, 1.5, 2.9))
	await _shot("m5_06_leon_down_the_aisle")
	leon.global_position = Vector3(-2.2, 0.0, 3.4)
	leon.rotation.y = atan2(1.0, 0.0)
	await _stand(Vector3(-4.6, 0.0, 3.9), Vector3(-2.2, 1.4, 3.4))
	await _shot("m5_07_leon_close")

func _hiding() -> void:
	threat.stalker.stand_down()
	await _stand(Vector3(7.1, 0.0, 3.0), sec.hiding.global_position)
	await _shot("m5_08_hiding_spot_prompt")
	sec.hiding.enter()
	await _shot("m5_09_hiding")
	sec.hiding.leave()

func _endings() -> void:
	for kind in ["escape", "secured", "caught"]:
		game.flow.show_ending(kind)
		await _shot("m5_end_" + kind)
		game.flow.hide_all()
