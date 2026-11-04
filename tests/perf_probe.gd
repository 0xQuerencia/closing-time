class_name PerfProbe
extends Node
## Frame-time probe with a real renderer. Run: godot --path . -- --perf [--no-shadows --no-ssao --no-msaa --no-glow --no-fx]

const SPOTS := [Vector3(-1, 1, 6), Vector3(-5, 1, 2), Vector3(5, 1, -3), Vector3(0, 1, 12)]

func run(game: Node) -> void:
	var args := OS.get_cmdline_user_args()
	var world: WorldEnvironment = game.find_children("*", "WorldEnvironment", true, false)[0]
	if "--no-ssao" in args:
		world.environment.ssao_enabled = false
	if "--no-glow" in args:
		world.environment.glow_enabled = false
	if "--no-msaa" in args:
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	if "--no-shadows" in args:
		for l in game.find_children("*", "Light3D", true, false):
			l.shadow_enabled = false
	if "--no-fx" in args:
		for c in game.get_children():
			if c is CanvasLayer:
				c.visible = false
	await get_tree().create_timer(2.0).timeout
	var cam := get_viewport().get_camera_3d()
	for spot in SPOTS:
		game.player.global_position = spot
		var times: Array[float] = []
		var t0 := Time.get_ticks_usec()
		for i in 240:
			cam.rotation.y += 0.02
			await get_tree().process_frame
			var t1 := Time.get_ticks_usec()
			times.append((t1 - t0) / 1000.0)
			t0 = t1
		times.sort()
		var avg := 0.0
		for t in times:
			avg += t
		avg /= times.size()
		print("PERF spot=%s avg=%.1fms p95=%.1fms max=%.1fms draws=%d prims=%d" % [spot, avg, times[int(times.size() * 0.95)], times[-1], RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
	get_tree().quit()
