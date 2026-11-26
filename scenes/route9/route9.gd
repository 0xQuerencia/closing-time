extends Node3D

const Progress = preload("res://gameplay/story/chapter_progress.gd")
const LENGTH := 460.0
const WagonArt = preload("res://scenes/opening/wagon_art.gd")
const RoadArt = preload("res://scenes/route9/route9_art.gd")
const WIPER_PARK := -.055
const WIPER_SWEEP := -1.18
var progress := Progress.new()
var travelled := 0.0
var speed := 0.0
var lateral := 0.0
var radio_on := false
var wipers_on := true
var wiper_clock := 0.0
var finishing := false
var car: Node3D
var wheel: Node3D
var wiper: Node3D
var speed_needle: Node3D
var windshield: ShaderMaterial
var status: Label
var caption_label: Label
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
	speed_needle.rotation.z = deg_to_rad(211.0 - speed * 2.237 * 4.0)
	wiper_clock = fposmod(wiper_clock+delta,3.2) if wipers_on else 0.0
	var sweep := .5-.5*cos(TAU*minf(wiper_clock/1.38,1.0))
	wiper.rotation.z = lerpf(WIPER_PARK,WIPER_SWEEP,sweep)
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
			windshield.set_shader_parameter("wipers_active",wipers_on)
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

func _build_road() -> void:
	var road := RoadArt.new()
	road.name = "Route 9 roadside"
	add_child(road)
	road.build(_center)

func _build_car() -> void:
	car = Node3D.new()
	add_child(car)
	var camera := Camera3D.new()
	camera.position = Vector3(-.38,1.24,.22)
	camera.fov = 75
	camera.current = true
	car.add_child(camera)
	var wagon := WagonArt.install(car)
	wheel = wagon.get_node("SteeringWheel")
	speed_needle = wagon.get_node("SpeedNeedle")
	windshield = ShaderMaterial.new()
	windshield.shader = preload("res://scenes/route9/windshield.gdshader")
	wagon.get_node("Windshield").material_override = windshield
	WagonArt.add_cabin_light(wagon)
	wiper = WagonArt.add_wiper(car)
	wiper.rotation.z = WIPER_PARK
	for x: float in [-.555,.555]:
		var light := SpotLight3D.new()
		light.name = "Left low beam" if x < 0.0 else "Right low beam"
		light.position = Vector3(x,.535,-2.34)
		light.rotation = Vector3(-.081 if x < 0.0 else -.061,-x*.14,0.0)
		light.light_color = Color("#f2d9a6")
		light.light_energy = 3.85
		light.spot_range = 52.0 if x < 0.0 else 57.0
		light.spot_angle = 17.0
		light.spot_angle_attenuation = 2.4
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
