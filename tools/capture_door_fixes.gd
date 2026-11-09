extends SceneTree
## godot --path . --always-on-top --script tools/capture_door_fixes.gd
## Real-renderer close-ups for the door-frame/seam pass.
const OUT := "res://local/screenshots/door-fixes"

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var market := (load("res://scenes/world/market_root.tscn") as PackedScene).instantiate()
	root.add_child(market)
	await process_frame
	market.player.enabled = false
	market.gameplay.flow.hide_all()
	var views: Array[Dictionary] = [
		{"name": "front_closed", "pos": Vector3(1.7, 0.0, 8.7), "target": Vector3(1.7, 1.1, 6.0), "front_open": false},
		{"name": "front_open", "pos": Vector3(1.7, 0.0, 8.7), "target": Vector3(1.7, 1.1, 6.0), "front_open": true},
		{"name": "front_inside", "pos": Vector3(1.7, 0.0, 4.65), "target": Vector3(1.7, 1.1, 6.0), "front_open": false},
		{"name": "rear_closed", "pos": Vector3(4.25, 0.0, -3.5), "target": Vector3(4.25, 1.1, -6.0)},
		{"name": "office_closed", "pos": Vector3(3.75, 0.0, -4.3), "target": Vector3(5.0, 1.1, -4.3)},
	]
	for view in views:
		market.gameplay.security.front_door.snap(bool(view.get("front_open", false)))
		market.gameplay.security.rear_door.snap(false)
		market.gameplay.security.office_door.snap(false)
		var pos: Vector3 = view["pos"]
		var target: Vector3 = view["target"]
		market.player.global_position = pos
		var d := target - (pos + Vector3(0, 1.62, 0))
		market.player.rotation = Vector3(0, atan2(-d.x, -d.z), 0)
		market.player.camera.rotation = Vector3(atan2(d.y, Vector2(d.x, d.z).length()), 0, 0)
		for i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		var path := "%s/%s.png" % [OUT, view["name"]]
		assert(image.save_png(path) == OK, "door capture failed: " + path)
	print("DOOR FIX CAPTURE COMPLETE")
	await market.finish_run(0)
