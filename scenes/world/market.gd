extends Node3D
## Static environment composition and reproducible M1 rendering hooks.
const Player = preload("res://scenes/world/inspection_player.gd")
const RetroEffect = preload("res://scenes/world/retro_effects.gd")
const RetroMaterials = preload("res://scenes/world/retro_material_style.gd")
var player: CharacterBody3D
var capture_mode := false
var samples: Array[float] = []
var gameplay: Gameplay
var ambient_dread: AmbientDread
## Where the title screen looks from: the far corner of the lot, storefront on the right, sky behind the logo.
const TITLE_EYE := Vector3(8.0, 0.0, 12.0)
const TITLE_AIM := Vector3(-6.0, 2.2, 6.0)

func _ready() -> void:
	capture_mode = "--capture" in OS.get_cmdline_user_args()
	for part in ["shell", "retail", "backrooms", "exterior"]:
		var scene := load("res://assets/models/%s.glb" % part) as PackedScene
		if scene:
			var instance := scene.instantiate()
			add_child(instance)
			RetroMaterials.apply_nearest_filter(instance)
	build_imported_props()
	build_collisions()
	build_glass()
	build_lighting()
	build_signage()
	build_markers()
	build_room_tone()
	add_child(RetroEffect.new())
	add_child(InteriorDressing.new())
	add_child(ExteriorDressing.new())
	add_child(FearsLook.new())
	ambient_dread = AmbientDread.new()
	add_child(ambient_dread)
	player = CharacterBody3D.new()
	player.set_script(Player)
	add_child(player)
	player.position = Vector3(-6.9, 0.05, 5.2)
	player.rotation.y = -0.36
	if capture_mode:
		player.enabled = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		capture_views(false)
	elif "--capture-m3" in OS.get_cmdline_user_args() or "--capture-assets" in OS.get_cmdline_user_args():
		player.enabled = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		capture_views(true)
	elif "--test-world" in OS.get_cmdline_user_args():
		player.enabled = false
		add_gameplay(false)  # the doors are gameplay objects now
		run_world_tests()
	elif "--test-gameplay" in OS.get_cmdline_user_args():
		player.enabled = false
		add_gameplay(false)
		var gameplay_tests := GameplayTests.new()
		add_child(gameplay_tests)
		gameplay_tests.run(self)
	elif "--test-story" in OS.get_cmdline_user_args():
		player.enabled = false
		add_gameplay(false)
		var story_tests := StoryTests.new()
		add_child(story_tests)
		story_tests.run_story(self)
	elif "--test-security" in OS.get_cmdline_user_args():
		player.enabled = false
		add_gameplay(false)
		var security_tests := SecurityTests.new()
		add_child(security_tests)
		security_tests.run_security(self)
	elif "--test-threat" in OS.get_cmdline_user_args():
		player.enabled = false
		add_gameplay(false)
		var threat_tests := ThreatTests.new()
		add_child(threat_tests)
		threat_tests.run_threat(self)
	elif "--capture-m5" in OS.get_cmdline_user_args():
		player.enabled = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		add_gameplay(false)
		var m5_capture := ThreatCapture.new()
		add_child(m5_capture)
		m5_capture.run(self)
	elif "--capture-hold" in OS.get_cmdline_user_args():
		player.enabled = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		add_gameplay(false)
		var hold_capture := HoldCapture.new()
		add_child(hold_capture)
		hold_capture.run(self)
	elif "--timed-playthrough" in OS.get_cmdline_user_args():
		player.require_mouse_capture = false
		player.enabled = false
		add_gameplay(false)
		var timed := TimedPlaythrough.new()
		add_child(timed)
		timed.run_timed(self)
	elif "--qa-gameplay" in OS.get_cmdline_user_args():
		player.require_mouse_capture = false
		add_gameplay(false)
		var gameplay_qa := GameplayQA.new()
		add_child(gameplay_qa)
		gameplay_qa.run_qa(self)
	elif "--perf" in OS.get_cmdline_user_args():
		player.require_mouse_capture = false
		add_gameplay(true)
		var perf_probe := PerfProbe.new()
		add_child(perf_probe)
		perf_probe.run(self)
	elif "--capture-gameplay" in OS.get_cmdline_user_args():
		player.enabled = false
		add_gameplay(false)
		var gameplay_capture := GameplayTests.new()
		add_child(gameplay_capture)
		gameplay_capture.capture(self)
	elif "--capture-reference" in OS.get_cmdline_user_args():
		player.enabled = false
		add_gameplay(false)
		var reference := ReferenceCapture.new()
		add_child(reference)
		reference.run(self)
	elif "--capture-m4" in OS.get_cmdline_user_args():
		player.enabled = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		add_gameplay(false)
		var m4_capture := SecurityCapture.new()
		add_child(m4_capture)
		m4_capture.run(self)
	elif "--capture-ui" in OS.get_cmdline_user_args():
		player.enabled = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		add_gameplay(false)
		var ui_capture: Node = (load("res://tests/ui_capture.gd") as Script).new()
		add_child(ui_capture)
		ui_capture.run(self)
	elif "--capture-atmosphere" in OS.get_cmdline_user_args():
		player.enabled = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		add_gameplay(false)
		var atmosphere_capture: Node = (load("res://tests/atmosphere_capture.gd") as Script).new()
		add_child(atmosphere_capture)
		atmosphere_capture.run(self)
	elif "--capture-customers" in OS.get_cmdline_user_args():
		player.enabled = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		add_gameplay(false)
		var recording = load("res://tests/customer_motion_capture.gd").new()
		add_child(recording)
		recording.run(self)
	elif "--capture-m3-gameplay" in OS.get_cmdline_user_args():
		player.enabled = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		add_gameplay(false)
		var visual_capture: Node = (load("res://tests/visual_capture_m3.gd") as Script).new()
		add_child(visual_capture)
		visual_capture.run(self)
	elif "--benchmark" in OS.get_cmdline_user_args():
		player.enabled = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		benchmark_views()
	else:
		add_gameplay(false)
		gameplay.persist_saves = true
		gameplay.flow.enable_persistence()
		player.enabled = false
		var spawn := Transform3D(player.global_transform)
		var spawn_look: Vector3 = player.camera.rotation
		gameplay.flow.start_requested.connect(func():
			player.global_transform = spawn
			player.camera.rotation = spawn_look
			player.enabled = true)
		# The title sits over the lit storefront from the car park, like the reference board.
		player.global_position = TITLE_EYE
		var gaze := TITLE_AIM - (player.global_position + Vector3(0, 1.62, 0))
		player.rotation = Vector3(0, atan2(-gaze.x, -gaze.z), 0)
		player.camera.rotation = Vector3(atan2(gaze.y, Vector2(gaze.x, gaze.z).length()), 0, 0)
		gameplay.flow.show_title()

func add_gameplay(auto_customers: bool) -> void:
	gameplay = Gameplay.new()
	add_child(gameplay)
	gameplay.setup(self, player, auto_customers)
	ambient_dread.bind_gameplay(gameplay)

func build_imported_props() -> void:
	# Office models replace the blockout computer set inside the existing office footprint.
	_add_visual("res://assets/models/office_props/desk_office.glb", Vector3(7.6, 0, -5.25))
	_add_visual("res://assets/models/office_props/chair_office.glb", Vector3(7.6, 0, -4.22), PI)
	_add_visual("res://assets/models/office_props/crt_monitor__static.glb", Vector3(7.9, .77, -5.43))
	_add_visual("res://assets/models/props/desktop_pc.glb", Vector3(7.35, .77, -5.38))
	_add_visual("res://assets/models/office_props/keyboard.glb", Vector3(7.9, .77, -4.96))
	_add_visual("res://assets/models/office_props/desk_phone.glb", Vector3(6.92, .77, -5.1))
	_add_visual("res://assets/models/props/mug.glb", Vector3(-8.02, .96, .15))
	_add_visual("res://assets/models/props/bottle_crate.glb", Vector3(6.45, 0, 1.25), PI / 2.0)
	_add_visual("res://assets/models/props/fire_extinguisher.glb", Vector3(4.74, 0, -1.0), PI / 2.0)
	_add_visual("res://assets/models/props/cctv_a.glb", Vector3(-8.0, 2.56, 5.78))
	_add_visual("res://assets/models/props/cctv_b.glb", Vector3(8.0, 2.56, -5.77), PI)
	_add_visual("res://assets/models/props/cctv_a.glb", Vector3(3.25, 2.72, 6.12), PI)

func _add_visual(path: String, point: Vector3, yaw: float = 0.0) -> Node3D:
	var scene := load(path) as PackedScene
	if scene == null:
		push_error("Visual asset failed to load: " + path)
		return null
	var instance := scene.instantiate() as Node3D
	instance.position = point
	instance.rotation.y = yaw
	add_child(instance)
	RetroMaterials.apply_nearest_filter(instance)
	return instance

func build_collisions() -> void:
	var entries = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/collisions.json"))
	for entry in entries:
		var body := StaticBody3D.new()
		body.name = entry.name
		body.position = Vector3(entry.p[0], entry.p[1], entry.p[2]) if entry.has("p") else Vector3.ZERO
		var collision := CollisionShape3D.new()
		if entry.has("points"):
			var shape := ConvexPolygonShape3D.new()
			var points := PackedVector3Array()
			for p in entry.points:
				points.append(Vector3(p[0],p[1],p[2]))
			shape.points = points
			collision.shape = shape
		else:
			var shape := BoxShape3D.new()
			shape.size = Vector3(entry.s[0], entry.s[1], entry.s[2])
			collision.shape = shape
		body.add_child(collision)
		add_child(body)

func glass_panel(pos: Vector3, size: Vector3, tint: Color) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.3
	material.metallic_specular = 0.12
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = pos
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)

func build_glass() -> void:
	for pair in [[-7.7,2.35],[-5.3,2.35],[-2.9,2.35],[-0.4,2.5],[3.0,0.94]]:
		glass_panel(Vector3(pair[0],1.67,6),Vector3(pair[1],2.06,.014),Color(.27,.36,.34,.065))
		var body := StaticBody3D.new()
		body.position = Vector3(pair[0],1.67,6)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(pair[1],2.06,.08)
		shape.shape = box
		body.add_child(shape)
		add_child(body)
	for i in range(6):
		var x := -7.1 + i * 1.57
		glass_panel(Vector3(x,1.2,-4.7),Vector3(1.37,2.06,.012),Color(.32,.43,.4,.05))
		if i == 3:
			_add_cooler_condensation(x)

func _add_cooler_condensation(x: float) -> void:
	var overlay := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.32, 1.98)
	overlay.mesh = quad
	overlay.position = Vector3(x, 1.2, -4.688)
	var film := ShaderMaterial.new()
	film.shader = load("res://scenes/world/fridge_condensation.gdshader")
	overlay.material_override = film
	overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(overlay)
	var animator := FridgeFog.new()
	animator.material = film
	add_child(animator)

func lamp(pos: Vector3, color: Color, energy: float, distance: float, shadows: bool = false) -> void:
	var light: Light3D
	if pos.y > 2.0:
		var spot := SpotLight3D.new()
		spot.spot_range = distance
		spot.spot_attenuation = 1.35
		spot.spot_angle = 78
		spot.spot_angle_attenuation = .35
		spot.rotation.x = -PI/2
		light = spot
	else:
		var omni := OmniLight3D.new()
		omni.omni_range = distance
		omni.omni_attenuation = 1.35
		light = omni
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.shadow_enabled = shadows
	light.shadow_bias = 0.025
	light.light_size = 0.0
	light.light_specular = 0.3
	light.shadow_blur = 1.6
	if pos.z < 6.4 and pos.y > 1.2:
		light.add_to_group("store_lights")  # on the store's circuit; the outdoor lamps are not
	add_child(light)

func build_lighting() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(.018,.03,.045)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(.54,.58,.61)
	env.ambient_light_energy = 0.32
	env.ssao_enabled = true
	env.ssao_radius = 0.32
	env.ssao_intensity = 0.48
	env.ssil_enabled = false
	env.ssil_intensity = 0.6
	env.glow_enabled = true
	env.glow_intensity = 0.12
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)
	for x in [-6.0,-2.0,1.4]:
		for z in [-3.8,.1,3.6]:
			lamp(Vector3(x,2.85,z),Color(1,.95,.83),0.85,5.3,x == -2.0)
	for z in [-4,1.5]:
		lamp(Vector3(6.9,2.84,z),Color(1,.91,.77),0.72,4.0,true)
	# Give the active stockroom aisle enough practical light to read carton labels.
	lamp(Vector3(6.9,2.84,3.0),Color(1,.91,.78),0.82,4.4,false)
	var utility_fixture := MeshInstance3D.new()
	var diffuser := CylinderMesh.new()
	diffuser.top_radius = .14
	diffuser.bottom_radius = .14
	diffuser.height = .045
	utility_fixture.mesh = diffuser
	utility_fixture.position = Vector3(4.25,3.12,-2.7)
	var finish := StandardMaterial3D.new()
	finish.albedo_color = Color(.76,.74,.64)
	finish.emission_enabled = true
	finish.emission = Color(.4,.36,.26)
	utility_fixture.material_override = finish
	add_child(utility_fixture)
	lamp(Vector3(4.25,2.95,-2.7),Color(1,.9,.74),.55,4.2,true)
	lamp(Vector3(4.2,2.6,3.3),Color(.68,.76,.69),.45,3.6)
	for x in [-6,-2,1.4]:
		lamp(Vector3(x,2.65,7.0),Color(1,.87,.68),1.3,5.4,true)
	lamp(Vector3(-9,5.1,15),Color(1,.68,.32),2.6,13,true)
	lamp(Vector3(12,5.1,23),Color(.57,.7,.85),2.0,13,true)
	var reflection := ReflectionProbe.new()
	reflection.position = Vector3(0,1.6,11)
	reflection.size = Vector3(25,7,18)
	reflection.box_projection = true
	reflection.intensity = 0.7
	reflection.max_distance = 35
	add_child(reflection)
	for x in [-4,3]:
		lamp(Vector3(x,4.08,7.65),Color(1,.94,.82),1.4,6.0)
	for i in range(3):
		lamp(Vector3(-6.4+i*3.14,1.6,-4.47),Color(.7,.85,.86),.35,2.5)

func text_label(value: String, pos: Vector3, size: int, pixel: float, color: Color, angle: float = 0, unshaded: bool = false) -> void:
	var label := Label3D.new()
	label.text = value
	label.position = pos
	label.font_size = size
	label.pixel_size = pixel
	label.modulate = color
	label.outline_size = 0
	label.shaded = not unshaded
	label.double_sided = false
	label.rotation.y = angle
	label.no_depth_test = false
	add_child(label)

func build_signage() -> void:
	text_label("MARLOW'S  MARKET",Vector3(-1.2,3.64,7.04),80,.008,Color(.9,.82,.65),0,true)
	text_label("GROCERIES   •   COFFEE   •   COLD DRINKS",Vector3(-2.8,2.51,6.05),36,.006,Color(.85,.8,.65))
	text_label("OPEN DAILY\n6 AM – MIDNIGHT",Vector3(-.35,1.6,6.025),32,.004,Color(.85,.8,.64))
	text_label("THANK YOU\nFOR SHOPPING LOCAL",Vector3(-4.05,1.47,6.025),27,.004,Color(.85,.8,.64),PI)
	text_label("COLD DRINKS",Vector3(-3.2,2.53,-5.061),42,.0035,Color(.8,.79,.68))
	for i in range(3):
		text_label(["01   SNACKS","02   PANTRY","03   EVERYDAY"][i],Vector3(-6+i*3,2.04,1.538),26,.0024,Color(.78,.74,.61))
	text_label("STAFF ONLY",Vector3(3.39,2.38,0),28,.004,Color(.3,.22,.12),-PI/2)
	text_label("OFFICE",Vector3(3.39,2.38,-4.3),28,.004,Color(.3,.22,.12),-PI/2)
	text_label("SHIFT NOTES\n\nCOUNT MILK BEFORE CLOSE\n\nREAR LATCH STICKS\n\n– D.",Vector3(8.835,1.7,-3.9),22,.0007,Color(.22,.19,.14),-PI/2)
	text_label("$1.99",Vector3(-6,.87,3.757),28,.002,Color(.22,.17,.11),PI)

func build_markers() -> void:
	var markers := Node3D.new()
	markers.name = "GameplayMarkers"
	add_child(markers)
	var points := {"PlayerStart":Vector3(-6.9,.05,5.2),"CheckoutPoint":Vector3(-5,0,3),"FrontDoor":Vector3(1.7,0,6),"RearDoor":Vector3(4.25,0,-6),"OfficeDoor":Vector3(5,0,-4.3),"CCTV_Front":Vector3(-8,2.6,5),"CCTV_Rear":Vector3(8,2.6,-7),"NPCEntrance":Vector3(1.7,0,7.8),"NPCExit":Vector3(1.7,0,9),"NPCQueue":Vector3(-4.8,0,2.9),"BreakerPanel":Vector3(4.8,1.5,2.8),"OfficePhone":Vector3(6.9,.9,-5.15),"InventoryTable":Vector3(6,.8,2.9)}
	for key in points:
		var marker := Marker3D.new()
		marker.name = key
		marker.position = points[key]
		marker.add_to_group(key)
		markers.add_child(marker)

func build_hint() -> void:
	var canvas := CanvasLayer.new()
	var label := Label.new()
	label.text = "WASD  walk     MOUSE  look     SHIFT  faster     E  use     F  inspect     Q  put down     1 2  reply     F6  pixels     F7  palette     F8  analog     ESC  release mouse"
	label.position = Vector2(24,24)
	label.modulate = Color(.82,.8,.7,.8)
	label.add_theme_font_size_override("font_size",14)
	canvas.add_child(label)
	add_child(canvas)
	await get_tree().create_timer(12).timeout
	var tween := create_tween()
	tween.tween_property(label,"modulate:a",0.0,2)

func capture_views(m3_views: bool) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1600,900)
	viewport.positional_shadow_atlas_size = 2048
	viewport.positional_shadow_atlas_16_bits = false
	viewport.world_3d = get_viewport().world_3d
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var asset_review := "--capture-assets" in OS.get_cmdline_user_args()
	var finish := RetroEffect.new()
	if asset_review:
		finish.pixelation_enabled = false
		finish.palette_enabled = false
		finish.analog_enabled = false
	viewport.add_child(finish)
	var shot_camera := Camera3D.new()
	shot_camera.keep_aspect = Camera3D.KEEP_WIDTH
	shot_camera.fov = 75.0
	shot_camera.near = 0.055
	viewport.add_child(shot_camera)
	shot_camera.current = true
	var output_dir := "res://local/screenshots/m3" if m3_views else "res://local/screenshots"
	var views := [
		["01_main_store_entrance",Vector3(-3.4,1.62,19.5),Vector3(-1,1.7,5.8)],
		["02_checkout_register",Vector3(-1.8,1.62,4.9),Vector3(-5.6,1.1,4.25)],
		["03_aisle_snacks",Vector3(-8.0,1.62,2.7),Vector3(-6.0,1.35,-1.2)],
		["04_aisle_pantry",Vector3(-4.55,1.62,2.7),Vector3(-3.0,1.3,-1.2)],
		["05_aisle_everyday",Vector3(1.45,1.62,2.7),Vector3(0.0,1.3,-1.2)],
		["06_coffee_station",Vector3(-7.5,1.62,1.5),Vector3(-8.25,1.2,-.6)],
		["07_refrigerated_drinks",Vector3(-1.5,1.62,-1.5),Vector3(-4.4,1.25,-5.2)],
		["08_office_cctv_desk",Vector3(5.8,1.55,-3.25),Vector3(7.55,1.0,-5.25)],
		["09_stockroom",Vector3(7.1,1.62,1.0),Vector3(8.2,1.1,4.25)],
		["10_rear_corridor",Vector3(4.23,1.62,2.5),Vector3(4.2,1.3,-5.8)],
		["11_parking_lot_night",Vector3(-10.0,1.62,19.0),Vector3(-4.9,1.0,13.0)]]
	if not m3_views:
		views = [
			["01_outside_to_store",Vector3(-3.4,1.62,19.5),Vector3(-1,1.7,5.8)],
			["02_checkout_to_aisles",Vector3(-7.2,1.62,5.2),Vector3(-2.4,1.3,-2.2)],
			["03_aisle_to_exit",Vector3(-1.5,1.62,-1.6),Vector3(.6,1.4,6.4)],
			["04_office_rear_corridor",Vector3(5.7,1.62,-3.15),Vector3(7.5,1.1,-5.2)],
			["04b_staff_corridor",Vector3(4.23,1.62,2.5),Vector3(4.2,1.3,-5.8)]]
	if asset_review:
		output_dir = "res://local/asset-polish/after"
		views = [
			["01_coffee_eye_height",Vector3(-7.2,1.62,.8),Vector3(-8.3,1.22,-.65)],
			["02_coffee_front",Vector3(-7.25,1.35,-.95),Vector3(-8.35,1.23,-.95)],
			["03_bottle_shoulders",Vector3(-4.4,1.62,-3.75),Vector3(-4.1,1.47,-4.85)],
			["04_snack_seals",Vector3(-7.0,1.62,-.7),Vector3(-6.23,1.45,-1.15)],
			["05_tin_rims",Vector3(1.05,1.62,-.7),Vector3(.25,1.42,-1.15)],
			["06_carton_folds",Vector3(-4.1,1.62,-.7),Vector3(-3.23,1.44,-1.15)],
			["07_store_context",Vector3(-7.2,1.62,5.2),Vector3(-2.4,1.3,-2.2)],
			["08_checkout_fixtures",Vector3(-5.4,1.62,6.0),Vector3(-5.9,1.02,4.35)],
			["09_stockroom_restock",Vector3(6.0,1.58,1.7),Vector3(6.55,.82,2.75)],
			["10_stockroom_hand_truck",Vector3(6.0,1.52,.95),Vector3(6.65,.78,.33)]]
	DirAccess.make_dir_recursive_absolute(output_dir)
	for view in views:
		shot_camera.position = view[1]
		shot_camera.look_at(view[2])
		await get_tree().create_timer(1.5).timeout
		await RenderingServer.frame_post_draw
		var error := viewport.get_texture().get_image().save_png("%s/%s.png" % [output_dir, view[0]])
		print("CAPTURE ",view[0]," status=",error)
	if asset_review:
		var metadata := FileAccess.open(output_dir + "/capture.json", FileAccess.WRITE)
		metadata.store_string(JSON.stringify({
			"date": Time.get_datetime_string_from_system(true),
			"engine": Engine.get_version_info().string,
			"renderer": RenderingServer.get_current_rendering_method(),
			"resolution": [1600,900],
			"source": "running Godot world scene",
			"retro_effects": false,
			"views": views
		}, "\t"))
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("CAPTURE COMPLETE renderer=",RenderingServer.get_current_rendering_method()," resolution=1600x900 output=",output_dir)
	await finish_run(0)

func run_world_tests() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var failures := 0
	# Raycasts verify actual engine collision at floor, shelves, glazing, doors.
	var checks := [
		["floor",Vector3(-1.5,1,-1),Vector3(-1.5,-1,-1),true],
		["shelf",Vector3(-1.5,.12,-1),Vector3(0,.12,-1),true],
		["front glass",Vector3(-4,1,5),Vector3(-4,1,7),true],
		["front doors (closed)",Vector3(1.7,1,5),Vector3(1.7,1,7),true],
		["rear door",Vector3(4.25,1,-5),Vector3(4.25,1,-7),true],
		["office door (closed)",Vector3(4.1,1,-4.3),Vector3(5.5,1,-4.3),true],
		["stock passage",Vector3(3,1,0),Vector3(5.5,1,0),false]]
	for check in checks:
		var query := PhysicsRayQueryParameters3D.create(check[1],check[2])
		query.exclude = [player.get_rid()]
		var hit := not get_world_3d().direct_space_state.intersect_ray(query).is_empty()
		if hit != check[3]:
			push_error("WORLD TEST FAIL: "+check[0])
			failures += 1
		else:
			print("WORLD TEST PASS: ",check[0])
	# Sweep the actual capsule through realistic routes and into obstructions. The entrance is walked with the doors open.
	gameplay.security.front_door.snap(true)
	gameplay.security.office_door.snap(true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	for route in [["entrance",Vector3(1.7,.03,5),Vector3(0,0,2),false],["wall",Vector3(-8,.03,3),Vector3(-2,0,0),true],["shelf",Vector3(-4.5,.03,0),Vector3(-2,0,0),true],["office",Vector3(4.1,.03,-4.3),Vector3(1.4,0,0),false]]:
		player.position = route[1]
		var blocked := player.test_move(player.global_transform,route[2])
		if blocked != route[3]:
			push_error("CAPSULE TEST FAIL: "+route[0])
			failures += 1
		else:
			print("CAPSULE TEST PASS: ",route[0])
	player.position = Vector3(-1.5,.03,4)
	player.rotation = Vector3.ZERO
	player.camera.rotation = Vector3.ZERO
	player.enabled = true
	player.require_mouse_capture = false # Headless display drivers cannot capture a mouse.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var press := InputEventKey.new()
	press.physical_keycode = KEY_W
	press.pressed = true
	Input.parse_input_event(press)
	var before := player.position
	for frame in range(45):
		await get_tree().physics_frame
	var release := InputEventKey.new()
	release.physical_keycode = KEY_W
	release.pressed = false
	Input.parse_input_event(release)
	var displacement := before.distance_to(player.position)
	if displacement > 1.0 and displacement < 1.7:
		print("INPUT TEST PASS: W moved capsule ",displacement," meters")
	else:
		push_error("INPUT TEST FAIL: W displacement="+str(displacement))
		failures += 1
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(100,35)
	player._unhandled_input(motion)
	if absf(player.rotation.y + .2) < .01 and absf(player.camera.rotation.x + .07) < .01:
		print("INPUT TEST PASS: mouse yaw and pitch")
	else:
		push_error("INPUT TEST FAIL: mouse rotation")
		failures += 1
	player.position = Vector3(1.7,-.10,10)
	player.rotation = Vector3.ZERO
	press.pressed = true
	Input.parse_input_event(press)
	for frame in range(120):
		await get_tree().physics_frame
	Input.parse_input_event(release)
	if player.position.z < 7.2 and player.position.y > -.03:
		print("INPUT TEST PASS: parking to sidewalk ramp ",player.position)
	else:
		push_error("INPUT TEST FAIL: curb ramp "+str(player.position))
		failures += 1
	player.enabled = false
	print("WORLD TESTS COMPLETE failures=",failures)
	await finish_run(1 if failures else 0)

func build_room_tone() -> void:
	var stream := load("res://assets/audio/refrigeration.wav") as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = stream.data.size() / 2
	for i in range(2):
		var x: float = [-6.4, -1.7][i]
		var source := AudioStreamPlayer3D.new()
		source.stream = stream
		source.position = Vector3(x,1.2,-5.0)
		source.pitch_scale = 1.0 + i * 0.025
		source.unit_size = 2
		source.max_distance = 15
		source.volume_db = -12
		source.add_to_group("power_hum")
		add_child(source)
		source.play()

func finish_run(code: int) -> void:
	for child in get_children():
		if child is ReflectionProbe:
			child.queue_free()
	for witness in get_tree().get_nodes_in_group("opening_witness"):
		if is_instance_valid(witness):
			witness.queue_free()
	if is_instance_valid(ambient_dread):
		ambient_dread.queue_free()
	_stop_audio_tree(self)
	# Let AudioServer retire stopped playbacks even when a test changed Engine.time_scale.
	await get_tree().create_timer(0.35, true, false, true).timeout
	get_tree().quit(code)

func _stop_audio_tree(node: Node) -> void:
	if node is AudioStreamPlayer:
		var player := node as AudioStreamPlayer
		player.stop()
		player.stream = null
	elif node is AudioStreamPlayer2D:
		var player := node as AudioStreamPlayer2D
		player.stop()
		player.stream = null
	elif node is AudioStreamPlayer3D:
		var player := node as AudioStreamPlayer3D
		player.stop()
		player.stream = null
	for child in node.get_children():
		_stop_audio_tree(child)

func _exit_tree() -> void:
	for child in get_children():
		if child is AudioStreamPlayer3D:
			child.stop()
			child.stream = null

func benchmark_views() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920,1080)
	viewport.world_3d = get_viewport().world_3d
	viewport.positional_shadow_atlas_size = 2048
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_2X
	add_child(viewport)
	viewport.add_child(RetroEffect.new())
	var camera := Camera3D.new()
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.fov = 75
	viewport.add_child(camera)
	camera.current = true
	get_viewport().disable_3d = true
	var frame_times: Array[float] = []
	for view in [[Vector3(-7.2,1.62,5.2),Vector3(-2,1.4,-2)], [Vector3(-1.5,1.62,-1.6),Vector3(0,1.4,7)], [Vector3(-3.4,1.62,19.5),Vector3(-1,1.7,5.8)]]:
		camera.position = view[0]
		camera.look_at(view[1])
		await get_tree().create_timer(2).timeout
		var last_tick := Time.get_ticks_usec()
		for frame in range(120):
			await get_tree().process_frame
			var tick := Time.get_ticks_usec()
			frame_times.append(float(tick-last_tick)/1000000.0)
			last_tick = tick
	var total := 0.0
	for delta in frame_times:
		total += delta
	frame_times.sort()
	var result := {"version":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"resolution":str(viewport.size),"gpu":RenderingServer.get_video_adapter_name(),"frames":frame_times.size(),"average_fps":frame_times.size()/total,"minimum_fps":1.0/frame_times[-1],"p95_frame_ms":frame_times[int(frame_times.size()*.95)]*1000,"note":"Three static views in an offscreen 1080p viewport, MSAA 2x; main viewport 3D disabled; vsync enabled. Not a full walking playthrough."}
	var file := FileAccess.open("res://local/benchmark.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  "))
	file.close()
	print("BENCHMARK ",JSON.stringify(result))
	viewport.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	await finish_run(0)
