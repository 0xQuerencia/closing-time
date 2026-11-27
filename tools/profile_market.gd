extends SceneTree
## Run after importing with a display and a temporary XDG data directory.
## godot --path . --audio-driver Dummy --resolution 1280x720 --script tools/profile_market.gd -- performance /absolute/output
## Use the same script and renderer settings on both revisions and run them sequentially.

const STORE := "res://scenes/world/market_root.tscn"
const WARMUP_FRAMES := 22
const APPROACH_START := Vector3(1.85, 1.52, 18.5)
const APPROACH_END := Vector3(1.85, 1.52, 11.0)
const SHOP_START := Vector3(1.0, 1.61, 4.9)
const SHOP_END := Vector3(-5.0, 1.61, 3.25)

var market: Node3D
var camera: Camera3D
var output := ""
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := args[0] if args.size() > 0 else "performance"
	output = args[1] if args.size() > 1 else ""
	if DisplayServer.get_name() == "headless" or mode not in FlowUI.GRAPHICS_MODES or (not output.is_empty() and not output.is_absolute_path()):
		printerr("Use a real renderer, a graphics mode and an optional absolute output directory.")
		quit(2)
		return
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var opening := ChapterProgress.new()
	if not opening.load_content():
		quit(2)
		return
	for chapter in 2:
		for event in opening.chapters[opening.index].required:
			opening.record(event)
		opening.advance()
	set_meta("closing_time_opening_preview", opening.snapshot())
	change_scene_to_file(STORE)
	await scene_changed
	market = current_scene
	for frame in 5:
		await process_frame
	var game: Gameplay = market.gameplay
	game.flow.settings.graphics_mode = mode
	game.flow.settings.reduced_flashes = true
	game.flow.apply_settings()
	market.player.enabled = false
	camera = Camera3D.new()
	camera.cull_mask = market.player.camera.cull_mask
	camera.fov = 70.0
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	market.add_child(camera)
	camera.make_current()
	print("PROFILE engine=%s adapter=%s resolution=%s mode=%s scale=%.2f" % [
		Engine.get_version_info().string, RenderingServer.get_video_adapter_name(), root.size, mode, root.scaling_3d_scale])

	await _view("approach", APPROACH_START, APPROACH_END, Vector3(.2, 1.65, 6.02), 48)
	await _view("sales-floor", SHOP_START, SHOP_END, Vector3(-4.5, 1.4, -4.65), 48)
	await _hold("cooler", Vector3(-3.15, 1.65, -3.1), Vector3(-2.5, 1.31, -4.85))
	await _hold("office", Vector3(7.45, 1.65, -4.0), Vector3(7.8, 1.17, -5.35))

	var grid := game.security.power
	grid.trip_all()
	await _hold("blackout", Vector3(4.15, 1.62, 2.4), Vector3(4.79, 1.45, 2.8))
	market.player.camera.global_transform = camera.global_transform
	game.security.flashlight.set_on(true)
	await _hold("blackout-phone-light", camera.position, Vector3(4.79, 1.45, 2.8))
	game.security.flashlight.set_on(false)
	grid.reset()
	await _hold("restored", SHOP_START, Vector3(-4.5, 1.4, -4.65))
	await _desk(game.security.cctv)
	await market.finish_run(failures)

func _hold(label: String, eye: Vector3, target: Vector3) -> void:
	await _view(label, eye, eye, target, 20)

func _view(label: String, start: Vector3, end: Vector3, target: Vector3, frames: int) -> void:
	camera.position = start
	camera.look_at(target)
	await _sample(label, frames, func(fraction: float):
		camera.position = start.lerp(end, fraction)
		camera.look_at(target))

func _desk(cctv: Cctv) -> void:
	cctv.enter()
	cctv.settle()
	cctv.select(1)
	while not cctv.is_live():
		await process_frame
	await _sample("cctv-desk", 30, func(_fraction: float): pass)
	var feed: SubViewport = cctv.feeds[1].viewport
	var shot := feed.get_texture().get_image()
	_save(shot, "cctv-rear-feed")
	var shades := {}
	for y in range(30, 175, 2):
		for x in range(0, shot.get_width(), 2):
			shades[floori(shot.get_pixel(x, y).get_luminance() * 32.0)] = true
	print("CCTV rear hall luminance bands: ", shades.size())
	if not output.is_empty():
		cctv._toggle_playback()
		if cctv.playback:
			cctv._scrub_tape(3)
			for frame in 3:
				await process_frame
			await RenderingServer.frame_post_draw
			_save(root.get_texture().get_image(), "cctv-archive")
	cctv.leave()
	cctv.settle()

func _sample(label: String, frames: int, pose: Callable) -> void:
	for frame in WARMUP_FRAMES:
		await process_frame
	if not output.is_empty():
		await RenderingServer.frame_post_draw
		_save(root.get_texture().get_image(), label)
	var times: Array[float] = []
	var draws: Array[int] = []
	var triangles: Array[int] = []
	for frame in frames:
		pose.call(float(frame) / float(frames - 1))
		var start := Time.get_ticks_usec()
		await process_frame
		times.append((Time.get_ticks_usec() - start) / 1000.0)
		draws.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		triangles.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	var total := 0.0
	for ms in times:
		total += ms
	times.sort()
	draws.sort()
	triangles.sort()
	print("METRIC %s fps=%.2f median_ms=%.1f p95_ms=%.1f max_ms=%.1f median_draws=%d median_primitives=%d" % [
		label, 1000.0 * frames / total, times[frames / 2], times[ceili(frames * .95) - 1], times[-1],
		draws[frames / 2], triangles[frames / 2]])

func _save(image: Image, label: String) -> void:
	if not output.is_empty() and image.save_png(output.path_join(label + ".png")) != OK:
		printerr("Could not write ", label)
		failures += 1
