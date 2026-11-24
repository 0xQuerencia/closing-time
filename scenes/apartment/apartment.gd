extends Node3D

const Player = preload("res://scenes/world/inspection_player.gd")
const Progress = preload("res://gameplay/story/chapter_progress.gd")
var progress := Progress.new()
var player: CharacterBody3D
var prompt: Label
var narration: Label
var checklist: Label
var targets: Dictionary = {}
var materials: Dictionary = {}
var selected := ""
var leaving := false

func _ready() -> void:
	GameInput.ensure()
	if not progress.load_content():
		push_error("Opening story could not load")
		return
	_build_room()
	_build_ui()
	player = CharacterBody3D.new()
	player.set_script(Player)
	player.position = Vector3(-1.6,.05,2.4)
	add_child(player)
	_refresh()
	narration.text = "I was twenty when I started working nights at Marlow's.\nIt was supposed to be a favor, just one extra shift."

func _physics_process(_delta: float) -> void:
	if player == null or leaving:
		return
	selected = ""
	var camera: Camera3D = player.camera
	var origin := camera.global_position
	var direction := -camera.global_basis.z
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 2.6)
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var node: Object = hit.collider
		if node.has_meta("story_item"):
			selected = str(node.get_meta("story_item"))
	prompt.text = "+\n[E] " + targets[selected].verb if targets.has(selected) else "+"

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(GameInput.INTERACT) and not selected.is_empty() and not leaving:
		_use(selected)
		get_viewport().set_input_as_handled()

func _use(id: String) -> void:
	if id == "apartment_exit":
		for required in ["shift_read","keys_taken","vest_taken"]:
			if not progress.events.has(required):
				narration.text = "I still need my phone, keys and work vest."
				return
		progress.record(id)
		if progress.advance():
			leaving = true
			get_tree().set_meta("closing_time_opening_preview", progress.snapshot())
			get_tree().change_scene_to_file("res://scenes/world/market_root.tscn")
		return
	if progress.record(id):
		narration.text = targets[id].body
		if id in ["keys_taken","vest_taken"]:
			targets[id].node.hide()
			targets[id].node.set_collision_layer_value(1, false)
		_refresh()
	elif targets.has(id):
		narration.text = targets[id].body

func _refresh() -> void:
	var lines: Array[String] = []
	for pair in [["shift_read","Read Dina's message"],["keys_taken","Take the keys"],["vest_taken","Get work vest"],["apartment_exit","Leave for work"]]:
		lines.append(("[x] " if progress.events.has(pair[0]) else "[ ] ") + pair[1])
	checklist.text = "FRIDAY / NOV 24, 2006   10:38 PM\n" + "\n".join(lines)

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var frame := Control.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(frame)
	checklist = Label.new()
	checklist.position = Vector2(22,22)
	checklist.add_theme_font_size_override("font_size",17)
	checklist.add_theme_color_override("font_shadow_color",Color.BLACK)
	checklist.add_theme_constant_override("shadow_offset_x",1)
	checklist.add_theme_constant_override("shadow_offset_y",2)
	frame.add_child(checklist)
	prompt = Label.new()
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	prompt.position -= Vector2(220,20)
	prompt.size = Vector2(440,60)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size",20)
	frame.add_child(prompt)
	narration = Label.new()
	narration.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	narration.offset_left = -360
	narration.offset_right = 360
	narration.offset_top = -144
	narration.offset_bottom = -24
	narration.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	narration.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	narration.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	narration.add_theme_font_size_override("font_size",23)
	narration.add_theme_color_override("font_shadow_color",Color.BLACK)
	narration.add_theme_constant_override("shadow_offset_y",2)
	frame.add_child(narration)

func _mat(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if materials.has(key):
		return materials[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = .95
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var image := Image.create(64,64,false,Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = key.hash()
	for y in range(64):
		for x in range(64):
			var v := rng.randf_range(.83,1.0)
			image.set_pixel(x,y,Color(v,v,v))
	material.albedo_texture = ImageTexture.create_from_image(image)
	materials[key] = material
	return material

func _box(pos: Vector3, size: Vector3, color: Color, solid := true) -> Node3D:
	var root: Node3D
	if solid:
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
		root = body
	else:
		root = Node3D.new()
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _mat(color)
	root.add_child(mesh)
	root.position = pos
	add_child(root)
	return root

func _target(id: String, verb: String, body: String, pos: Vector3, size: Vector3, color: Color) -> void:
	var node := _box(pos,size,color)
	node.set_meta("story_item",id)
	targets[id] = {"verb":verb,"body":body,"node":node}

func _build_room() -> void:
	var wall := Color("#8c8978")
	var floor_color := Color("#62564b")
	var wood := Color("#705640")
	var fabric := Color("#615f56")
	var dark := Color("#303332")
	_box(Vector3(0,-.10,0),Vector3(7,.2,9),floor_color)
	_box(Vector3(0,2.75,0),Vector3(7,.12,9),wall.darkened(.2))
	for x in [-3.5,3.5]:
		_box(Vector3(x,1.35,0),Vector3(.15,2.7,9),wall)
	_box(Vector3(0,1.35,-4.5),Vector3(7,2.7,.15),wall)
	_box(Vector3(-1.8,1.35,4.5),Vector3(3.4,2.7,.15),wall)
	_box(Vector3(2.55,1.35,4.5),Vector3(1.9,2.7,.15),wall)
	_box(Vector3(.65,2.52,4.5),Vector3(1.5,.35,.15),wall)
	_target("apartment_exit","Leave apartment","Time for work.",Vector3(.65,1.15,4.45),Vector3(1.28,2.28,.12),wood)
	_box(Vector3(1.14,1.05,4.33),Vector3(.10,.04,.09),Color("#9b8a5d"),false)
	# Bed, blanket and pillow.
	_box(Vector3(-2.35,.22,-2.45),Vector3(1.45,.4,2.10),wood)
	_box(Vector3(-2.35,.47,-2.45),Vector3(1.4,.16,2.02),Color("#a5a18e"))
	_box(Vector3(-2.35,.57,-2.18),Vector3(1.42,.06,1.45),fabric)
	_box(Vector3(-2.35,.61,-3.12),Vector3(.78,.13,.42),Color("#b3b0a0"))
	# Desk and paper/photo/phone, all original geometry.
	_box(Vector3(.65,.70,-3.91),Vector3(1.7,.10,.76),wood)
	for x in [-.10,1.40]:
		_box(Vector3(x,.34,-3.91),Vector3(.09,.68,.64),wood)
	_target("shift_read","Read phone","Dina: Could you cover closing tonight? I'll leave the checklist on the counter.\nKay: You owe me breakfast if you're working again.",Vector3(.48,.79,-3.62),Vector3(.065,.045,.13),dark)
	_target("rent_notice","Read rent reminder","Rent due December 1. I'd written 'extra shift?' in the margin.",Vector3(.88,.76,-3.73),Vector3(.22,.014,.29),Color("#d1c5a3"))
	_target("kay_photo","Look at photograph","Kay and me last June. It felt like a different year.",Vector3(1.25,.87,-4.14),Vector3(.19,.23,.035),Color("#89795f"))
	_box(Vector3(-.02,.79,-4.11),Vector3(.18,.07,.18),dark,false)
	_box(Vector3(-.02,.97,-4.11),Vector3(.036,.35,.036),dark,false)
	_box(Vector3(-.02,1.15,-4.11),Vector3(.24,.10,.22),Color("#b8a276"),false)
	# Kitchen cabinets and worn appliances.
	_box(Vector3(2.93,.43,-1.55),Vector3(.95,.86,2.6),wood)
	_box(Vector3(2.93,.90,-1.55),Vector3(1.02,.08,2.68),Color("#99978b"))
	_box(Vector3(2.95,1.0,-2.29),Vector3(.57,.12,.58),dark,false)
	_box(Vector3(3.02,.83,1.2),Vector3(.80,1.65,.76),Color("#a7a596"))
	_box(Vector3(2.60,1.12,1.2),Vector3(.06,.43,.04),dark,false)
	# Entry table, keys and vest.
	_box(Vector3(-2.74,.72,3.70),Vector3(1.10,.10,.55),wood)
	for x in [-3.18,-2.3]:
		_box(Vector3(x,.35,3.70),Vector3(.08,.7,.48),wood)
	_target("keys_taken","Pick up keys","Keys. I checked the ring twice, like I always did.",Vector3(-2.63,.80,3.58),Vector3(.10,.04,.075),Color("#a99c64"))
	_target("vest_taken","Take work vest","The maroon vest still smelled like coffee.",Vector3(-3.36,1.23,2.82),Vector3(.12,.55,.48),Color("#683d40"))
	# Window, night and curtain.
	_box(Vector3(0,1.69,-4.40),Vector3(1.25,.97,.045),Color("#283c45"),false)
	for x in [-.63,.63]:
		_box(Vector3(x,1.69,-4.36),Vector3(.07,1.10,.08),wood,false)
	for y in [1.17,2.21]:
		_box(Vector3(0,y,-4.36),Vector3(1.32,.07,.08),wood,false)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#151c24")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#9b9a8d")
	env.ambient_light_energy = .52
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(-.02,1.12,-3.85)
	lamp.light_color = Color("#efc895")
	lamp.light_energy = 1.3
	lamp.omni_range = 5.0
	add_child(lamp)
	var fill := OmniLight3D.new()
	fill.position = Vector3(1.0,2.35,2.0)
	fill.light_color = Color("#c4c1aa")
	fill.light_energy = .9
	fill.omni_range = 6.0
	add_child(fill)
