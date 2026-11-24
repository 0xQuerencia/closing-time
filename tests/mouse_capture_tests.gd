extends SceneTree
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool,label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
	else:
		print("MOUSE CAPTURE TEST PASS: ",label)

func _settle() -> void:
	for i in range(4):
		await process_frame

func _look(player: CharacterBody3D, label: String) -> void:
	player.require_mouse_capture = DisplayServer.get_name() != "headless"
	await _settle()
	var yaw: float = player.rotation.y
	var pitch: float = player.camera.rotation.x
	var motion := InputEventMouseMotion.new()
	motion.position = root.get_visible_rect().size / 2.0
	motion.global_position = motion.position
	motion.relative = Vector2(50,25)
	Input.parse_input_event(motion)
	await _settle()
	var k: float = player.sensitivity
	check(absf(player.rotation.y - (yaw - .1*k)) < .005 and absf(player.camera.rotation.x - (pitch - .05*k)) < .005,label)

func run() -> void:
	change_scene_to_file("res://scenes/world/market_root.tscn")
	await scene_changed
	await _settle()
	var market = current_scene
	check(market.gameplay.flow.mode == "title","game opens on title")
	market.gameplay.flow.press("start")
	await scene_changed
	await _settle()
	var apartment = current_scene
	check(apartment.scene_file_path.ends_with("apartment.tscn"),"New Game loads apartment")
	await _look(apartment.player,"centered motion reaches apartment player")
	apartment._use("apartment_exit")
	check(not apartment.leaving,"apartment exit requires preparation")
	for id in ["shift_read","keys_taken","vest_taken"]:
		apartment._use(id)
	apartment._use("apartment_exit")
	await scene_changed
	await _settle()
	var route = current_scene
	check(route.scene_file_path.ends_with("route9.tscn"),"apartment leads to Route 9")
	route._arrive()
	await scene_changed
	await _settle()
	market = current_scene
	check(market.gameplay.director.production != null,"road leads to production market")
	check(market.gameplay.director.production.progress.current_id() == "handover","market begins at handover")
	await _look(market.player,"centered motion reaches market player")
	print("MOUSE CAPTURE TESTS COMPLETE failures=",failures)
	quit(1 if failures else 0)
