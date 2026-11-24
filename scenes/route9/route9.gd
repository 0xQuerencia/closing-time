extends Node3D

const PSX = preload("res://assets/models/psx_pack/asset_loader.gd")

const Progress = preload("res://gameplay/story/chapter_progress.gd")
const RetroMaterials = preload("res://scenes/world/retro_material_style.gd")
const LENGTH := 460.0
var progress := Progress.new()
var travelled := 0.0
var speed := 0.0
var lateral := 0.0
var radio_on := false
var wipers_on := true
var finishing := false
var car: Node3D
var wheel: Node3D
var wiper: Node3D
var status: Label
var caption_label: Label
var materials: Dictionary = {}
var rain: AudioStreamPlayer
var engine: AudioStreamPlayer
var skip: Button

func _ready() -> void:
	if not progress.load_content() or not progress.restore(get_tree().get_meta("closing_time_opening_preview", {})) or progress.current_id() != "route9":
		get_tree().change_scene_to_file.call_deferred("res://scenes/apartment/apartment.tscn")
		return
	progress.record("drive_started")
	OpeningCheckpoint.write(progress.snapshot())
	_build_road()
	_build_car()
	add_child(preload("res://scenes/world/retro_effects.gd").new())
	_build_ui()
	_build_audio()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(delta: float) -> void:
	if finishing or car == null:
		return
	var throttle := Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)
	var brake := Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)
	var steer := float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	var target_speed := 16.0 if throttle else 0.0
	speed = move_toward(speed, 0.0 if brake else target_speed, delta * (12.0 if brake else 4.0))
	lateral = clampf(lateral + steer * delta * speed * .20, -1.35, 1.35)
	travelled = minf(LENGTH, travelled + speed * delta)
	var center := _center(travelled)
	var next := _center(travelled + 2.0)
	car.position = Vector3(center + lateral,0,-travelled)
	car.rotation.y = atan2(-(next-center),2.0)
	wheel.rotation.z = lerpf(wheel.rotation.z, -steer*.55, minf(1.0,delta*5.0))
	wiper.rotation.z = sin(Time.get_ticks_msec()*.004)*.65 if wipers_on else -.7
	engine.pitch_scale = .72 + speed/25.0
	if travelled >= 80.0:
		skip.show()
	if travelled >= 120.0 and travelled < 155.0:
		caption_label.text = "The bypass had been open for three years. Hardly anyone took the old road anymore.  [E] Read sign"
	elif travelled >= 330.0 and travelled < 390.0:
		caption_label.text = "There was Marlow's, at the end of the tree line."
	elif travelled >= 430.0:
		caption_label.text = "Pull in and stop.  [E] Park at Marlow's"
	else:
		caption_label.text = "Local radio: light rain overnight." if radio_on else ""
	status.text = "ROUTE 9     10:52 PM\n%02d mph    %d m to Marlow's" % [int(speed*2.237), int(LENGTH-travelled)]
	if travelled >= LENGTH and speed <= .4:
		_arrive()

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_R:
			radio_on = not radio_on
			if radio_on:
				progress.record("radio_tuned")
				OpeningCheckpoint.write(progress.snapshot())
		KEY_T:
			wipers_on = not wipers_on
		KEY_E:
			if travelled >= 120.0 and travelled < 155.0:
				progress.record("bypass_sign")
				OpeningCheckpoint.write(progress.snapshot())
				caption_label.text = "Through traffic: use the new bypass."
			elif travelled >= 430.0 and speed <= 2.0:
				_arrive()

func _arrive() -> void:
	if finishing:
		return
	progress.record("market_arrived")
	if not progress.advance():
		return
	finishing = true
	OpeningCheckpoint.write(progress.snapshot())
	get_tree().set_meta("closing_time_opening_preview", progress.snapshot())
	get_tree().change_scene_to_file("res://scenes/world/market_root.tscn")

func _center(t: float) -> float:
	return sin(t*.012)*7.0 + sin(t*.025)*2.0

func _mat(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = .9
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		materials[key] = m
	return materials[key]

func _box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _mat(color)
	node.position = pos
	parent.add_child(node)
	return node

func _build_road() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#20282e")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#89949b")
	env.ambient_light_energy = .45
	env.fog_enabled = true
	env.fog_light_color = Color("#20282e")
	env.fog_density = .021
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20061124
	var tree_asset := PSX.mesh_and_material("pine_tree")
	var trees := MultiMesh.new()
	trees.transform_format = MultiMesh.TRANSFORM_3D
	trees.mesh = tree_asset.mesh
	trees.instance_count = 240
	var grove := MultiMeshInstance3D.new()
	grove.multimesh = trees
	grove.material_override = tree_asset.material
	add_child(grove)
	for i in range(240):
		var t := rng.randf_range(-30.0,LENGTH+50)
		var side := -1.0 if i%2 == 0 else 1.0
		var h := rng.randf_range(.65,1.65)
		var basis := Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3(h,h,h))
		trees.set_instance_transform(i,Transform3D(basis,Vector3(_center(t)+side*rng.randf_range(9.0,35.0),0,-t)))
	for i in range(65):
		var t := float(i)*8.0-20.0
		var center := _center(t)
		var next := _center(t+8.0)
		var yaw := atan2(-(next-center),8.0)
		var mid := Vector3((center+next)*.5,-.03,-t-4.0)
		var asphalt := _box(self,mid,Vector3(7.0,.12,8.55),Color("#42474a"))
		asphalt.rotation.y = yaw
		var road_surface := asphalt.material_override as StandardMaterial3D
		if road_surface.albedo_texture == null:
			road_surface.albedo_texture = load("res://assets/models/exterior_asphalt.png") as Texture2D
			road_surface.albedo_color = Color("#a8a8a8")
			road_surface.uv1_scale = Vector3(2,2,1)
		var dash := _box(self,mid+Vector3(0,.071,0),Vector3(.085,.012,3.2),Color("#c1a35c"))
		dash.rotation.y = yaw
		for side in [-1.0,1.0]:
			var edge := _box(self,mid+Vector3(side*3.35,.068,0),Vector3(.09,.012,8.5),Color("#adafa4"))
			edge.rotation.y = yaw
	_box(self,Vector3(0,-.28,-230),Vector3(100,.4,540),Color("#41483a"))
	_sign("OLD ROUTE 9\nTHROUGH TRAFFIC: BYPASS",130.0)
	_sign("MARLOW'S MARKET\nOPEN UNTIL MIDNIGHT",385.0)
	# Use the exact authored market shell visible in the next scene, not a cube proxy.
	var shop := Vector3(_center(456)+17.0,0,-456)
	var storefront := preload("res://assets/models/shell.glb").instantiate() as Node3D
	storefront.rotation.y = -PI / 2.0
	storefront.position = shop
	add_child(storefront)
	RetroMaterials.apply_nearest_filter(storefront)
	var lamp := OmniLight3D.new()
	lamp.position = shop+Vector3(-8,2.4,0)
	lamp.light_color = Color("#e6ca9a")
	lamp.light_energy = 2.2
	lamp.omni_range = 18
	add_child(lamp)

func _sign(body: String,t: float) -> void:
	var at := Vector3(_center(t)+4.9,0,-t)
	var sign_mesh := PSX.place(self,"roadside_sign",at)
	# The authored sign mesh is retained; make the actual story text readable.
	if sign_mesh != null:
		var label := Label3D.new()
		label.text = body
		label.font_size = 38
		label.pixel_size = .0027
		label.position = Vector3(0,1.65,.048)
		label.modulate = Color("#e2dfcd")
		sign_mesh.add_child(label)


func _build_car() -> void:
	car = Node3D.new()
	add_child(car)
	var camera := Camera3D.new()
	camera.position = Vector3(-.38,1.24,.22)
	camera.fov = 75
	camera.current = true
	car.add_child(camera)
	var dash := Color("#363b39")
	PSX.place(car,"dashboard",Vector3.ZERO)
	_box(car,Vector3(0,1.72,-.8),Vector3(1.65,.10,.12),dash)
	for x in [-.82,.82]:
		var pillar := _box(car,Vector3(x,1.3,-.84),Vector3(.09,.87,.12),dash)
		pillar.rotation.x = -.15
	_box(car,Vector3(0,1.64,-.22),Vector3(1.72,.09,1.35),dash)
	wheel = Node3D.new()
	wheel.position = Vector3(-.38,.91,-.35)
	car.add_child(wheel)
	PSX.place(wheel,"steering_wheel",Vector3.ZERO)
	PSX.place(car,"rearview_mirror",Vector3(0,1.52,-.60))
	PSX.place(car,"car_seat",Vector3(.38,.12,.18),PI)
	PSX.place(car,"gear_lever",Vector3(0,.44,-.25))
	wiper = Node3D.new()
	wiper.position = Vector3(.30,.93,-.9)
	car.add_child(wiper)
	PSX.place(wiper,"wiper",Vector3.ZERO)
	for x in [-.55,.55]:
		var light := SpotLight3D.new()
		light.position = Vector3(x,.6,-1.1)
		light.rotation.x = -.055
		light.light_color = Color("#f2d9a6")
		light.light_energy = 3.2
		light.spot_range = 48
		light.spot_angle = 32
		car.add_child(light)

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)
	status = Label.new()
	status.position = Vector2(24,24)
	status.add_theme_font_size_override("font_size",20)
	root.add_child(status)
	caption_label = Label.new()
	caption_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	caption_label.offset_left = -420
	caption_label.offset_right = 420
	caption_label.offset_top = -112
	caption_label.offset_bottom = -60
	caption_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption_label.add_theme_font_size_override("font_size",21)
	root.add_child(caption_label)
	var controls := Label.new()
	controls.text = "W/S accelerate/brake   A/D steer   R radio   T wipers"
	controls.position = Vector2(24,86)
	controls.add_theme_font_size_override("font_size",17)
	root.add_child(controls)
	skip = Button.new()
	skip.text = "Skip drive"
	skip.position = Vector2(24,120)
	skip.pressed.connect(_arrive)
	skip.hide()
	root.add_child(skip)

func _build_audio() -> void:
	engine = AudioStreamPlayer.new()
	var wav := AudioStreamWAV.new()
	var data := PackedByteArray()
	data.resize(22050*2)
	for i in range(22050):
		var t := float(i)/22050
		var value := sin(TAU*48*t)*.45+sin(TAU*96*t)*.16+sin(TAU*144*t)*.07
		data.encode_s16(i*2,int(value*12000))
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = 22050
	engine.stream = wav
	engine.volume_db = -18
	add_child(engine)
	engine.play()
