extends SceneTree
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var market := (load("res://scenes/world/market_root.tscn") as PackedScene).instantiate()
	root.add_child(market)
	var player = market.player
	player.require_mouse_capture = DisplayServer.get_name() != "headless" # Real renderer uses actual capture.
	for frame in range(3):
		await process_frame
	if market.gameplay.flow.mode != "title":
		failures += 1
		push_error("the game did not open on the title screen")
	market.gameplay.flow.press("start")
	for frame in range(3):
		await process_frame
	var yaw: float = player.rotation.y
	var pitch: float = player.camera.rotation.x
	var motion := InputEventMouseMotion.new()
	motion.position = root.get_visible_rect().size / 2.0
	motion.global_position = motion.position
	motion.relative = Vector2(50, 25)
	Input.parse_input_event(motion)
	for frame in range(3):
		await process_frame
	# The real launch path loads the player's saved settings, so expect the turn at their mouse sensitivity.
	var k: float = player.sensitivity
	if absf(player.rotation.y - (yaw - 0.1 * k)) > 0.005 or absf(player.camera.rotation.x - (pitch - 0.05 * k)) > 0.005:
		failures += 1
		push_error("HUD blocked centered mouse look: yaw=%s pitch=%s" % [player.rotation.y - yaw, player.camera.rotation.x - pitch])
	else:
		print("MOUSE CAPTURE TEST PASS: centered motion passes through actual game HUD and turns yaw/pitch")
	print("MOUSE CAPTURE TESTS COMPLETE failures=", failures)
	await market.finish_run(1 if failures else 0)
