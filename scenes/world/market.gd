extends Node3D
## Static environment composition and reproducible M1 rendering hooks.
const Player = preload("res://scenes/world/inspection_player.gd")
var player: CharacterBody3D
var capture_mode := false
var samples: Array[float] = []

func _ready() -> void:
	capture_mode = "--capture" in OS.get_cmdline_user_args()
	for part in ["shell", "retail", "backrooms", "exterior"]:
		var scene := load("res://assets/models/%s.glb" % part) as PackedScene
		if scene:
			add_child(scene.instantiate())
	build_collisions()
	build_glass()
	build_lighting()
	build_signage()
	build_markers()
	player = CharacterBody3D.new()
	player.set_script(Player)
	add_child(player)
	player.position = Vector3(-6.9, 0.05, 5.2)
	player.rotation.y = -0.36
	if capture_mode:
		player.enabled = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		capture_views()
	elif "--test-world" in OS.get_cmdline_user_args():
		player.enabled = false
		run_world_tests()
	else:
		build_hint()

func build_collisions() -> void:
	var entries = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/collisions.json"))
	for entry in entries:
		var body := StaticBody3D.new()
		body.name = entry.name
		body.position = Vector3(entry.p[0], entry.p[1], entry.p[2])
		var collision := CollisionShape3D.new()
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
	material.roughness = 0.16
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
		glass_panel(Vector3(-7.1+i*1.57,1.2,-4.7),Vector3(1.37,2.06,.012),Color(.32,.43,.4,.05))
	# Entrance is open for M1 access; the leaf is fixed alongside the right-hand pane.
	glass_panel(Vector3(2.57,1.12,5.45),Vector3(.016,2.18,1.05),Color(.4,.5,.45,.1))

func lamp(pos: Vector3, color: Color, energy: float, distance: float, shadows: bool = false) -> void:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = distance
	light.omni_attenuation = 1.35
	light.shadow_enabled = shadows
	light.shadow_bias = 0.04
	add_child(light)

func build_lighting() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(.018,.03,.045)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(.49,.54,.57)
	env.ambient_light_energy = 0.32
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)
	for x in [-6.0,-2.0,1.4]:
		for z in [-3.8,.1,3.6]:
			lamp(Vector3(x,2.85,z),Color(1,.89,.71),1.25,5.3,true)
	for z in [-4,1.5]:
		lamp(Vector3(6.9,2.84,z),Color(1,.86,.65),1.05,4.0,true)
	lamp(Vector3(4.2,2.6,3.3),Color(.68,.76,.69),.45,3.6)
	for x in [-6,-2,1.4]:
		lamp(Vector3(x,2.65,7.0),Color(1,.87,.68),1.3,5.4,true)
	lamp(Vector3(-9,5.1,15),Color(1,.68,.32),2.6,13,true)
	lamp(Vector3(12,5.1,23),Color(.57,.7,.85),2.0,13,true)
	for i in range(3):
		lamp(Vector3(-6.4+i*3.14,1.6,-4.47),Color(.7,.85,.86),.35,2.5)

func text_label(value: String, pos: Vector3, size: int, pixel: float, color: Color, angle: float = 0) -> void:
	var label := Label3D.new()
	label.text = value
	label.position = pos
	label.font_size = size
	label.pixel_size = pixel
	label.modulate = color
	label.outline_size = 0
	label.rotation.y = angle
	label.no_depth_test = false
	add_child(label)

func build_signage() -> void:
	text_label("MARLOW'S  MARKET",Vector3(-1.2,3.64,7.04),80,.008,Color(.83,.8,.65))
	text_label("GROCERIES   •   COFFEE   •   COLD DRINKS",Vector3(-2.8,2.51,6.05),36,.006,Color(.85,.8,.65))
	text_label("OPEN DAILY\n6 AM – MIDNIGHT",Vector3(-.35,1.6,6.025),32,.004,Color(.85,.8,.64))
	text_label("THANK YOU\nFOR SHOPPING LOCAL",Vector3(-4.05,1.47,6.025),27,.004,Color(.85,.8,.64),PI)
	text_label("COLD DRINKS",Vector3(-3.2,2.53,-5.1),42,.006,Color(.8,.79,.68))
	for i in range(3):
		text_label(["01   SNACKS","02   PANTRY","03   EVERYDAY"][i],Vector3(-6+i*3,2.04,1.52),26,.006,Color(.78,.74,.61))
	text_label("STAFF ONLY",Vector3(3.39,2.38,0),28,.004,Color(.3,.22,.12),-PI/2)
	text_label("OFFICE",Vector3(3.39,2.38,-4.3),28,.004,Color(.3,.22,.12),-PI/2)
	text_label("KEEP REAR DOOR CLOSED",Vector3(4.25,1.72,-5.951),23,.003,Color(.8,.78,.64))
	text_label("SHIFT NOTES\n\nCOUNT MILK BEFORE CLOSE\n\nREAR LATCH STICKS\n\n– D.",Vector3(8.835,1.68,-3.65),22,.002,Color(.22,.19,.14),-PI/2)
	text_label("$1.99",Vector3(-6,.87,3.757),28,.002,Color(.22,.17,.11),PI)
	text_label("COFFEE\nFRESH UNTIL 10",Vector3(-8.83,1.98,-.6),32,.004,Color(.25,.2,.13),PI/2)

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
	label.text = "WASD  walk     MOUSE  look     SHIFT  faster     B  head bob     ESC  release mouse"
	label.position = Vector2(24,24)
	label.modulate = Color(.82,.8,.7,.8)
	label.add_theme_font_size_override("font_size",14)
	canvas.add_child(label)
	add_child(canvas)
	await get_tree().create_timer(12).timeout
	var tween := create_tween()
	tween.tween_property(label,"modulate:a",0.0,2)

func capture_views() -> void:
	var views := [
		["01_outside_to_store",Vector3(-3.4,1.62,16.4),Vector3(-1,1.7,5.8)],
		["02_checkout_to_aisles",Vector3(-7.2,1.62,5.2),Vector3(-2.4,1.3,-2.2)],
		["03_aisle_to_exit",Vector3(-1.5,1.62,-1.6),Vector3(.6,1.4,6.4)],
		["04_office_rear_corridor",Vector3(5.7,1.62,-3.15),Vector3(7.5,1.1,-5.2)]]
	DirAccess.make_dir_recursive_absolute("res://local/screenshots")
	for view in views:
		player.position = view[1] - Vector3(0,1.62,0)
		player.rotation = Vector3.ZERO
		player.camera.rotation = Vector3.ZERO
		player.camera.look_at(view[2])
		await get_tree().create_timer(1.5).timeout
		await RenderingServer.frame_post_draw
		var error := get_viewport().get_texture().get_image().save_png("res://local/screenshots/%s.png" % view[0])
		print("CAPTURE ",view[0]," status=",error)
	print("CAPTURE COMPLETE renderer=",RenderingServer.get_current_rendering_method()," resolution=",get_viewport().get_visible_rect().size)
	get_tree().quit()

func run_world_tests() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var failures := 0
	# Raycasts verify actual engine collision at floor, shelves, glazing, doors.
	var checks := [
		["floor",Vector3(-1.5,1,-1),Vector3(-1.5,-1,-1),true],
		["shelf",Vector3(-1.5,.12,-1),Vector3(0,.12,-1),true],
		["front glass",Vector3(-4,1,5),Vector3(-4,1,7),true],
		["front entrance",Vector3(1.7,1,5),Vector3(1.7,1,7),false],
		["rear door",Vector3(4.25,1,-5),Vector3(4.25,1,-7),true],
		["office passage",Vector3(4.1,1,-4.3),Vector3(5.5,1,-4.3),false],
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
	# Sweep the actual capsule through realistic routes and into obstructions.
	for route in [["entrance",Vector3(1.7,.03,5),Vector3(0,0,2),false],["wall",Vector3(-8,.03,3),Vector3(-2,0,0),true],["shelf",Vector3(-4.5,.03,0),Vector3(-2,0,0),true],["office",Vector3(4.1,.03,-4.3),Vector3(1.4,0,0),false]]:
		player.position = route[1]
		var blocked := player.test_move(player.global_transform,route[2])
		if blocked != route[3]:
			push_error("CAPSULE TEST FAIL: "+route[0])
			failures += 1
		else:
			print("CAPSULE TEST PASS: ",route[0])
	print("WORLD TESTS COMPLETE failures=",failures)
	get_tree().quit(1 if failures else 0)
