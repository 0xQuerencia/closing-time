extends SceneTree
## Same views for the supplied baseline and art pass. Also runs with Godot's dummy renderer.

const PROGRESS = preload("res://gameplay/story/chapter_progress.gd")
var output := ""
var headless := false
var failed := false

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	output = OS.get_environment("CLOSING_OPENING_CAPTURE_DIR")
	if not output.is_absolute_path():
		printerr("CLOSING_OPENING_CAPTURE_DIR must be an absolute path")
		quit(2)
		return
	headless = DisplayServer.get_name() == "headless"
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,800)
	root.title = "Closing Time opening capture"
	print("CAPTURE MODE ",DisplayServer.get_name()," / ",RenderingServer.get_current_rendering_method())

	await _scene("res://scenes/apartment/apartment.tscn")
	var apartment := current_scene
	apartment.player.enabled = false
	if apartment.player.position.distance_to(Vector3(-1.6,.05,2.4)) > .001:
		_fail("Apartment spawn moved")
	_hide_canvas(apartment)
	_budget("apartment",apartment)
	_apartment_colliders(apartment)
	await _shot("01-apartment-spawn",apartment.player.camera,Vector3(0,1.69,-4.38))

	var progress = PROGRESS.new()
	if not progress.load_content():
		_fail("Opening story content missing")
		quit(1)
		return
	_complete(progress)
	set_meta("closing_time_opening_preview",progress.snapshot())
	await _scene("res://scenes/route9/route9.tscn")
	var road := current_scene
	road.set_process(false)
	_hide_canvas(road)
	var driver := root.get_camera_3d()
	if driver.position.distance_to(Vector3(-.38,1.24,.22)) > .001:
		_fail("Driver eye moved")
	_budget("route9",road)
	_drive_pose(road,48)
	driver.rotation.x = -.16
	await _shot("03-cockpit",driver,road.car.to_global(Vector3(-.38,.91,-.40)))
	_drive_pose(road,106)
	driver.rotation.x = 0
	await _shot("04-night-road",driver,Vector3(road._center(124),0,-124))
	_drive_pose(road,421)
	var frontage := road.find_child("Marlow's roadside frontage",true,false) as Node3D
	if frontage != null:
		var sign := frontage.find_children("*","Label3D",false,false)[0] as Label3D
		if not driver.is_position_in_frustum(sign.global_position):
			_fail("Actual Marlow's sign is outside the reveal camera")
		print("REVEAL sign=",sign.global_position)
	await _shot("04b-marlow-reveal",driver,Vector3(road._center(449)+3.4,1.9,-449))

	_complete(progress)
	set_meta("closing_time_opening_preview",progress.snapshot())
	await _scene("res://scenes/world/market_root.tscn")
	var market := current_scene
	for i in range(7):
		await process_frame
	market.player.enabled = false
	market.gameplay.hud.visible = false
	market.gameplay.phone_ui.visible = false
	market.gameplay.flow.hide_all()
	if market.player.position.distance_to(Vector3(1.85,-.1,12.55)) > .051:
		_fail("Market arrival moved")
	_budget("market_lot",market.get_node("OriginalExterior"))
	_budget("market_dressing",market.get_node("ExteriorDressing"))
	await _shot("05-arrival-spawn",market.player.camera,Vector3(1.70,1.42,6.08))
	var framing := Camera3D.new()
	market.add_child(framing)
	framing.current = true
	framing.keep_aspect = Camera3D.KEEP_WIDTH
	framing.fov = 58
	framing.position = Vector3(-1.79,1.29,18.42)
	framing.look_at(Vector3(-4.9,.65,13.0))
	await _shot("02-car-exterior",framing,Vector3(-4.9,.65,13.0))
	framing.fov = 70
	framing.position = Vector3(-2.05,1.49,21.80)
	framing.look_at(Vector3(-.35,1.69,7.50))
	await _shot("06-storefront-and-wagon",framing,Vector3(-4.9,.72,13.0))
	if failed:
		await market.finish_run(1)
	else:
		await market.finish_run(0)

func _scene(path: String) -> void:
	var result := change_scene_to_file(path)
	if result != OK:
		printerr("Failed to open ",path," (",result,")")
		quit(1)
		return
	await scene_changed

func _complete(progress: RefCounted) -> void:
	for event in progress.chapters[progress.index].required:
		progress.record(event)
	if not progress.advance():
		_fail("Unable to create capture checkpoint")

func _hide_canvas(scene: Node) -> void:
	for child in scene.get_children():
		if child is CanvasLayer:
			child.hide()

func _drive_pose(road: Node3D, distance: float) -> void:
	road.travelled = distance
	road.speed = 12.0
	road._process(0.0)
	road.wiper.rotation.z = -.48

func _apartment_colliders(apartment: Node3D) -> void:
	var shapes: Array[String] = []
	for child in apartment.get_children():
		if child is StaticBody3D:
			var shape: BoxShape3D = child.get_child(0).shape
			shapes.append("%s%s:%s" % [str(child.get_meta("story_item","")),str(child.position),str(shape.size)])
	shapes.sort()
	print("COLLIDERS apartment count=",shapes.size()," sha256=",";".join(shapes).sha256_text())

func _shot(label: String, camera: Camera3D, focus: Vector3) -> void:
	if not camera.is_position_in_frustum(focus):
		_fail(label+" reference is outside the camera")
	print("CAMERA ",label," eye=",camera.global_position," forward=",-camera.global_basis.z,
		" fov=",camera.fov," near=",camera.near," far=",camera.far," aspect=",camera.keep_aspect,
		" reference=",focus)
	if headless:
		return
	for i in 24:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var result := image.save_png(output.path_join(label+".png"))
	print("FRAME ",label," draw_calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		" primitives=",Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		" resolution=",image.get_size()," result=",result)
	if result != OK:
		_fail("Could not save "+label)

func _budget(label: String, scene: Node) -> void:
	var meshes := {}
	var materials := {}
	var submitted := 0
	var regular := 0
	var grouped := 0
	var batches := 0
	for node in scene.find_children("*","GeometryInstance3D",true,false):
		var mesh: Mesh
		var copies := 1
		if node is MeshInstance3D:
			mesh = node.mesh
			regular += 1
		elif node is MultiMeshInstance3D and node.multimesh != null:
			mesh = node.multimesh.mesh
			copies = node.multimesh.instance_count
			grouped += copies
			batches += 1
		if mesh == null:
			continue
		if not meshes.has(mesh):
			meshes[mesh] = _triangles(mesh)
		submitted += int(meshes[mesh]) * copies
		for i in mesh.get_surface_count():
			var finish: Material = node.get_active_material(i) if node is MeshInstance3D else node.material_override
			if finish == null:
				finish = mesh.surface_get_material(i)
			if finish != null:
				materials[finish] = true
	var unique := 0
	for count in meshes.values():
		unique += int(count)
	print("BUDGET ",label," unique_triangles=",unique," unculled_instance_triangles=",submitted,
		" unique_meshes=",meshes.size()," individual_mesh_instances=",regular,
		" grouped_instances=",grouped," groups=",batches," material_resources=",materials.size())

func _triangles(mesh: Mesh) -> int:
	var count := 0
	for i in mesh.get_surface_count():
		if mesh is ArrayMesh and mesh.surface_get_primitive_type(i) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arrays := mesh.surface_get_arrays(i)
		var indices = arrays[Mesh.ARRAY_INDEX]
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		count += floori((indices.size() if indices != null and not indices.is_empty() else vertices.size()) / 3.0)
	return count

func _fail(message: String) -> void:
	failed = true
	printerr("CAPTURE FAIL ",message)
