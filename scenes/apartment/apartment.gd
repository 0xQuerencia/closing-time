extends Node3D

const Player = preload("res://scenes/world/inspection_player.gd")
const RetroEffect = preload("res://scenes/world/retro_effects.gd")
const Progress = preload("res://gameplay/story/chapter_progress.gd")
var progress := Progress.new()
var player: CharacterBody3D
var prompt: Label
var narration: Label
var checklist: Label
var targets: Dictionary = {}
const ApartmentArt = preload("res://scenes/apartment/apartment_art.gd")
var art := ApartmentArt.new()
var selected := ""
var leaving := false
var epilogue := ""
var prologue: CanvasLayer
var prologue_text: Label
var prologue_page := 0
const PROLOGUE_LINES := ["This happened in November 2006. I was working nights at a little market outside Bellwick.","It was just a favor for someone at work. I thought I would be home before one.","There was something I didn't know about the man who came in that night."]

func _ready() -> void:
	GameInput.ensure()
	if not progress.load_content():
		push_error("Opening story could not load")
		return
	if get_tree().has_meta("closing_time_epilogue"):
		epilogue = str(get_tree().get_meta("closing_time_epilogue"))
		get_tree().remove_meta("closing_time_epilogue")
	elif get_tree().has_meta("closing_time_opening_preview"):
		progress.restore(get_tree().get_meta("closing_time_opening_preview"))
		get_tree().remove_meta("closing_time_opening_preview")
	_build_room()
	RetroEffect.install(self)
	_build_ui()
	player = CharacterBody3D.new()
	player.set_script(Player)
	# Start in the clear central aisle, close enough to read the room's furniture.
	# Keep the original 75 degree gameplay lens and full movement controls.
	player.position = Vector3(-.55,.05,-.15)
	add_child(player)
	player.camera.rotation.x = -.075
	if not epilogue.is_empty():
		_build_epilogue()
		return
	for id in ["keys_taken","vest_taken"]:
		if progress.events.has(id):
			targets[id].node.hide()
			targets[id].node.set_collision_layer_value(1,false)
	OpeningCheckpoint.write(progress.snapshot())
	_refresh()
	if get_tree().has_meta("closing_time_new_game"):
		get_tree().remove_meta("closing_time_new_game")
		_show_prologue()
	narration.text = "I was twenty when I started working nights at Marlow's.\nIt was supposed to be a favor, just one extra shift."

func _physics_process(_delta: float) -> void:
	if player == null or leaving or is_instance_valid(prologue):
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
	if is_instance_valid(prologue):
		if event is InputEventKey and event.pressed and not event.echo:
			if event.physical_keycode == KEY_ESCAPE:
				_close_prologue()
			elif event.physical_keycode in [KEY_ENTER,KEY_SPACE,KEY_E]:
				_next_prologue()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(GameInput.INTERACT) and not selected.is_empty() and not leaving:
		get_viewport().set_input_as_handled()
		_use(selected)

func _use(id: String) -> void:
	if not epilogue.is_empty():
		if id == "apartment_exit":
			leaving = true
			get_tree().change_scene_to_file("res://scenes/world/market_root.tscn")
		elif targets.has(id):
			narration.text = targets[id].body
		return
	if id == "apartment_exit":
		for required in ["shift_read","keys_taken","vest_taken"]:
			if not progress.events.has(required):
				narration.text = "I still need my phone, keys and work vest."
				return
		progress.record(id)
		if progress.advance():
			leaving = true
			OpeningCheckpoint.write(progress.snapshot())
			get_tree().set_meta("closing_time_opening_preview", progress.snapshot())
			get_tree().change_scene_to_file("res://scenes/route9/route9.tscn")
		return
	if progress.record(id):
		narration.text = targets[id].body
		if id in ["keys_taken","vest_taken"]:
			targets[id].node.hide()
			targets[id].node.set_collision_layer_value(1, false)
		OpeningCheckpoint.write(progress.snapshot())
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

func _solid(pos: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	body.position = pos
	add_child(body)
	return body

func _target(id: String, verb: String, body: String, pos: Vector3, size: Vector3) -> void:
	var node := _solid(pos,size)
	node.set_meta("story_item",id)
	art.target(node,id)
	targets[id] = {"verb":verb,"body":body,"node":node}

func _build_room() -> void:
	_solid(Vector3(0,-.10,0),Vector3(7,.2,9))
	_solid(Vector3(0,2.75,0),Vector3(7,.12,9))
	for x in [-3.5,3.5]:
		_solid(Vector3(x,1.35,0),Vector3(.15,2.7,9))
	_solid(Vector3(0,1.35,-4.5),Vector3(7,2.7,.15))
	_solid(Vector3(-1.8,1.35,4.5),Vector3(3.4,2.7,.15))
	_solid(Vector3(2.55,1.35,4.5),Vector3(1.9,2.7,.15))
	_solid(Vector3(.65,2.52,4.5),Vector3(1.5,.35,.15))
	_target("apartment_exit","Leave apartment","Time for work.",Vector3(.65,1.15,4.45),Vector3(1.28,2.28,.12))
	_solid(Vector3(-2.35,.22,-2.45),Vector3(1.45,.4,2.10))
	_solid(Vector3(-2.35,.47,-2.45),Vector3(1.4,.16,2.02))
	_solid(Vector3(-2.35,.57,-2.18),Vector3(1.42,.06,1.45))
	_solid(Vector3(-2.35,.61,-3.12),Vector3(.78,.13,.42))
	_solid(Vector3(.65,.70,-3.91),Vector3(1.7,.10,.76))
	for x in [-.10,1.40]:
		_solid(Vector3(x,.34,-3.91),Vector3(.09,.68,.64))
	_target("shift_read","Read phone","Dina: Could you cover closing tonight? I'll leave the checklist on the counter.\nKay: You owe me breakfast if you're working again.",Vector3(.48,.79,-3.62),Vector3(.065,.045,.13))
	_target("rent_notice","Read rent reminder","Rent due December 1. I'd written 'extra shift?' in the margin.",Vector3(.88,.76,-3.73),Vector3(.22,.014,.29))
	_target("kay_photo","Look at photograph","Kay and me last June. It felt like a different year.",Vector3(1.25,.87,-4.14),Vector3(.19,.23,.035))
	_solid(Vector3(2.93,.43,-1.55),Vector3(.95,.86,2.6))
	_solid(Vector3(2.93,.90,-1.55),Vector3(1.02,.08,2.68))
	_solid(Vector3(3.02,.83,1.2),Vector3(.80,1.65,.76))
	_solid(Vector3(-2.74,.72,3.70),Vector3(1.10,.10,.55))
	for x in [-3.18,-2.3]:
		_solid(Vector3(x,.35,3.70),Vector3(.08,.7,.48))
	_target("keys_taken","Pick up keys","Keys. I checked the ring twice, like I always did.",Vector3(-2.63,.80,3.58),Vector3(.10,.04,.075))
	_target("vest_taken","Take work vest","The maroon vest still smelled like coffee.",Vector3(-3.36,1.23,2.82),Vector3(.12,.55,.48))
	art.build(self,not epilogue.is_empty())
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#151c24")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#b6a99c")
	env.ambient_light_energy = .56
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)

func _build_epilogue() -> void:
	checklist.text = "MONDAY / DEC 11, 2006   8:17 AM"
	for id in targets:
		if id != "apartment_exit":
			targets[id].node.hide()
			targets[id].node.set_collision_layer_value(1,false)
	targets["apartment_exit"].verb = "Return to title"
	var headline := "Marlow's closed pending investigation."
	var account := "I kept wondering what would have happened if I'd found the records sooner."
	if epilogue == "evidence_preserved":
		headline = "Police reopen missing employee inquiry after new documents emerge."
		account = "Dina gave her statement. The papers weren't proof of everything, but somebody was finally listening."
	elif epilogue == "rescued":
		headline = "Police respond to intrusion at local market."
		account = "The officers told me I was safe. It took a while before I could believe them."
	_target("epilogue_paper","Read the newspaper",headline + "\n" + account,Vector3(.88,.77,-3.73),Vector3(.30,.022,.33))
	_target("epilogue_phone","Read Kay's message","Kay: Breakfast is on me. No arguments.",Vector3(.48,.79,-3.62),Vector3(.065,.045,.13))
	narration.text = "I didn't go back to work. For the first time in weeks, I had nowhere to be."
	for child in get_children():
		if child is WorldEnvironment:
			child.environment.background_color = Color("#8b9295")
			child.environment.ambient_light_color = Color("#d5cfc2")
			child.environment.ambient_light_energy = .85

func _show_prologue() -> void:
	player.enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	prologue = CanvasLayer.new()
	prologue.layer = 40
	add_child(prologue)
	var shade := ColorRect.new()
	shade.color = Color(.025,.025,.025)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	prologue.add_child(shade)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.offset_left = -340
	box.offset_right = 340
	box.offset_top = -130
	box.add_theme_constant_override("separation",24)
	shade.add_child(box)
	prologue_text = Label.new()
	prologue_text.text = PROLOGUE_LINES[0]
	prologue_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prologue_text.add_theme_font_override("font",preload("res://assets/fonts/original/marlow.fnt"))
	prologue_text.add_theme_font_size_override("font_size",28)
	box.add_child(prologue_text)
	for row in [["Continue",_next_prologue],["Skip",_close_prologue]]:
		var button := Button.new()
		button.text = row[0]
		button.flat = true
		button.pressed.connect(row[1])
		box.add_child(button)

func _next_prologue() -> void:
	prologue_page += 1
	if prologue_page >= PROLOGUE_LINES.size():
		_close_prologue()
	else:
		prologue_text.text = PROLOGUE_LINES[prologue_page]

func _close_prologue() -> void:
	if is_instance_valid(prologue):
		prologue.queue_free()
		prologue = null
	player.enabled = true
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
