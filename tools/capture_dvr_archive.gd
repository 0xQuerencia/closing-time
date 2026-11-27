extends SceneTree
## Capture the optional production tape with the actual rear-hall lens and original cast rig.
## Run after import with a display: godot --path . --script tools/capture_dvr_archive.gd

const OUTPUT := "res://assets/story/dvr"
const EVAN := {
	"height": .95, "width": .93, "coat": Color("#8c8173"), "pants": Color("#666772"),
	"skin": Color("#c7a98a"), "hair": Color("#4c3931"), "style": "short", "glasses": false,
}
const FRAME_POSITIONS := [Vector3(4.27, .05, -6.75), Vector3(4.38, .05, -5.55),
	Vector3(4.33, .05, -3.15), Vector3(4.18, .05, -.9)]

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("The archive capture needs a real renderer.")
		quit(1)
		return
	change_scene_to_file("res://scenes/world/market_root.tscn")
	await scene_changed
	var market := current_scene
	var game: Gameplay = market.gameplay
	var cctv := game.security.cctv
	cctv.set_process(false)
	cctv.get_node("../ClerkProxy").hide()
	game.flow.hide_all()
	market.player.enabled = false
	var feed: Dictionary = cctv.feeds[1]
	var viewport: SubViewport = feed.viewport
	var lens: Camera3D = feed.camera
	var grade := market.find_children("*", "WorldEnvironment", false, false)[0].environment.duplicate() as Environment
	grade.ambient_light_energy = .56
	grade.ambient_light_color = Color(.68, .73, .70)
	grade.fog_enabled = false
	lens.environment = grade
	for at in [Vector3(4.31, 2.48, -4.3), Vector3(4.32, 2.48, -.83)]:
		var lamp := OmniLight3D.new()
		lamp.position = at
		lamp.light_energy = 1.8
		lamp.light_color = Color(.85, .94, .89)
		lamp.omni_range = 4.5
		market.add_child(lamp)
	for overlay in [feed.title, feed.stamp, feed.rec, feed.lost, feed.door]:
		overlay.hide()
	var evan := OriginalCast.instantiate("evan")
	OriginalCast._customize(evan, "evan", EVAN)
	market.add_child(evan)
	var pose: AnimationPlayer = evan.find_children("*", "AnimationPlayer", true, false)[0]
	pose.play("Walk")
	pose.pause()
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var failed := false
	for index in FRAME_POSITIONS.size():
		game.security.rear_door.snap(index != 0)
		evan.visible = index != 0
		evan.position = FRAME_POSITIONS[index]
		evan.rotation.y = .1 if index < 3 else -.23
		pose.seek(.16 + index * .19, true)
		for frame in 5:
			await process_frame
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		image.resize(160, 120, Image.INTERPOLATE_LANCZOS)
		# The historical camera has a noisy low-light monochrome sensor.
		var rng := RandomNumberGenerator.new()
		rng.seed = 8192006 + index
		for y in image.get_height():
			for x in image.get_width():
				var tone := pow(image.get_pixel(x, y).get_luminance(), .88)
				tone += rng.randf_range(-.023, .023) - .016 if y % 3 == 0 else rng.randf_range(-.023, .023)
				image.set_pixel(x, y, Color(tone * .93, tone, tone * .97))
		var result := image.save_png(OUTPUT.path_join("rear-hall-%d.png" % index))
		print("DVR CAPTURE ", index, " ", result)
		failed = failed or result != OK
	await market.finish_run(1 if failed else 0)
