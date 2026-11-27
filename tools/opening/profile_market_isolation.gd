extends SceneTree
## Recording-only Market causal breakdown. The game and its defaults are not modified.
const PROGRESS = preload("res://gameplay/story/chapter_progress.gd")
const SAMPLES := 6
var output := ""
var failed := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	output = OS.get_environment("CLOSING_MARKET_DIAGNOSTIC_DIR")
	if not output.is_absolute_path() or DisplayServer.get_name() == "headless":
		printerr("Market diagnostics require a graphical renderer and an absolute output path")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,800)
	var progress = PROGRESS.new()
	if not progress.load_content():
		quit(2)
		return
	for stage in 2:
		for id in progress.chapters[progress.index].required:
			progress.record(id)
		if not progress.advance():
			quit(2)
			return
	set_meta("closing_time_opening_preview",progress.snapshot())
	if change_scene_to_file("res://scenes/world/market_root.tscn") != OK:
		quit(2)
		return
	await scene_changed
	var market := current_scene
	var flow: FlowUI = market.gameplay.flow
	market.player.enabled = false
	market.gameplay.hud.visible = false
	market.gameplay.phone_ui.visible = false
	flow.hide_all()
	for i in 4:
		await process_frame
	var point := Camera3D.new()
	point.name = "Matched Market diagnostics camera"
	market.add_child(point)
	point.keep_aspect = Camera3D.KEEP_WIDTH
	point.fov = 75.0
	point.position = Vector3(-3.058332,1.500838,20.24989)
	point.look_at(Vector3(-.42,1.74,7.18))
	point.make_current()
	print("ISOLATION camera ",point.global_position," aim ",-point.global_basis.z," fov ",point.fov,
		" renderer ",RenderingServer.get_current_rendering_method())
	var lights := market.find_children("*","Light3D",true,false)
	var original_mode := str(flow.settings.graphics_mode)
	var original_retro := bool(flow.settings.retro)
	# No changes made to a player's persisted preferences, even in a reused capture environment.
	flow.persist_settings = false
	paused = true
	await _sample("00-unchanged-startup",flow,lights)
	for mode in ["balanced","performance","safe","quality"]:
		flow.settings.graphics_mode = mode
		flow.apply_settings()
		await _sample("preset-"+mode,flow,lights)
	flow.settings.graphics_mode = "balanced"
	flow.apply_settings()
	var authored := {}
	for node in lights:
		var light := node as Light3D
		authored[light] = light.shadow_enabled
		light.shadow_enabled = false
	await _sample("balanced-no-shadow-maps",flow,lights)
	for node in authored:
		(node as Light3D).shadow_enabled = bool(authored[node])
	await _hide_sample("balanced-no-lot-fill-lights",flow,lights,lights,_is_lot_fill)
	await _hide_sample("balanced-no-interior-lights",flow,lights,lights,_is_store_light)
	var geometry := market.find_children("*","MeshInstance3D",true,false)
	await _hide_sample("balanced-no-translucent-meshes",flow,lights,geometry,_is_translucent)
	await _hide_sample("balanced-no-stockroom-geometry",flow,lights,market.get_children(),_is_stockroom)
	await _hide_sample("balanced-no-retail-geometry",flow,lights,market.get_children(),_is_retail)
	flow.settings.graphics_mode = original_mode
	flow.settings.retro = original_retro
	flow.apply_settings()
	paused = false
	await market.finish_run(1 if failed else 0)

func _is_lot_fill(node: Node3D) -> bool:
	var lamp := node as Light3D
	return lamp != null and lamp.global_position.z >= 6.4 and lamp.is_in_group("quality_fill_shadows")

func _is_store_light(node: Node3D) -> bool:
	return node.is_in_group("store_lights")

func _is_stockroom(node: Node3D) -> bool:
	return node.scene_file_path.ends_with("/backrooms.glb")

func _is_retail(node: Node3D) -> bool:
	return node.scene_file_path.ends_with("/retail.glb")

func _is_translucent(node: Node) -> bool:
	var mesh := node as MeshInstance3D
	if mesh == null or mesh.mesh == null or mesh.mesh.get_surface_count() < 1:
		return false
	var finish := mesh.get_active_material(0) as BaseMaterial3D
	if finish == null:
		return false
	return finish.transparency in [BaseMaterial3D.TRANSPARENCY_ALPHA, BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS]

func _hide_sample(label: String, flow: FlowUI, lights: Array, candidates: Array, select: Callable) -> void:
	var hidden: Array[Node3D] = []
	for node in candidates:
		var element := node as Node3D
		if element != null and element.visible and select.call(element):
			element.hide()
			hidden.append(element)
	if hidden.is_empty():
		printerr("No objects matched diagnostic scope: ",label)
		failed = true
	print("ISOLATION ",label," temporarily_hidden=",hidden.size())
	await _sample(label,flow,lights)
	for element in hidden:
		element.show()

func _sample(label: String, flow: FlowUI, lights: Array) -> void:
	var view := root.get_viewport_rid()
	var durations: Array[float] = []
	for i in 3:
		await RenderingServer.frame_post_draw
	for i in SAMPLES:
		var started := Time.get_ticks_usec()
		await RenderingServer.frame_post_draw
		durations.append((Time.get_ticks_usec()-started)/1000.0)
	durations.sort()
	var active := 0
	var shadows := 0
	for node in lights:
		var light := node as Light3D
		if light.is_visible_in_tree():
			active += 1
			shadows += int(light.shadow_enabled)
	var global_draws := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var visible_draws := RenderingServer.viewport_get_render_info(view,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
	var shadow_draws := RenderingServer.viewport_get_render_info(view,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
	var canvas_draws := RenderingServer.viewport_get_render_info(view,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_CANVAS,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
	print("MARKET-PROFILE ",JSON.stringify({"view":label,"mode":str(flow.settings.graphics_mode),
		"scale":root.scaling_3d_scale,"msaa":root.msaa_3d,"lights":active,"shadow_lights":shadows,
		"total_draws":global_draws,"visible_draws":visible_draws,"shadow_draws":shadow_draws,
		"canvas_draws":canvas_draws,"render_median_ms":durations[SAMPLES >> 1],
		"render_max_ms":durations[-1],"samples":SAMPLES}))
	var shot := root.get_texture().get_image()
	if shot == null or shot.is_empty() or shot.save_png(output.path_join(label+".png")) != OK:
		failed = true
