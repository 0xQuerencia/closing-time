class_name Security
extends Node
## Composition root for M4: doors, electrics, CCTV, the rear sensor and the phone light.
## Story decisions live in SecurityBeats; this class only builds and wires physical systems.
const FRONT_CENTRE := Vector3(1.69, 0.0, 6.0)
const REAR_CENTRE := Vector3(4.25, 0.0, -6.0)
var game
var world: Node3D
var power: PowerGrid
var breaker: BreakerPanel
var cctv: Cctv
var sensor: RearSensor
var front_door: Door
var rear_door: Door
var flashlight: Flashlight
var intruder: Intruder
var office_door: Door
var hiding: HidingSpot
var landline: Landline

func build(owner_game) -> Security:
	game = owner_game
	world = game.world
	name = "Security"
	game.player.add_to_group("player")
	power = PowerGrid.new()
	add_child(power)
	power.build(world)
	_build_front_door()
	_build_rear_door()
	_build_stoop()
	breaker = BreakerPanel.new().build(world, power)
	cctv = Cctv.new().build(game, power)
	sensor = RearSensor.new().build(world, rear_door, game.clock, power)
	cctv.sensor = sensor
	flashlight = Flashlight.new()
	add_child(flashlight)
	flashlight.build(game.player)
	_build_office_door()
	hiding = HidingSpot.new().build(game)
	landline = Landline.new().build(game)
	game.checkout.terminal.powered = func(): return power.powered("register")
	game.shift.door_ajar = func(): return rear_door.is_open
	game.shift.latch_locked.connect(func(): rear_door.set_locked(true))
	game.shift.latch_unlocked.connect(func(): rear_door.set_locked(false))
	return self

func _material(color: Color, rough := 0.6, metallic := 0.0, alpha := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metallic
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if alpha:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func _bar(parent: Node3D, size: Vector3, pos: Vector3, material: Material) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = material
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)

func _texture_material(path: String, alpha := false) -> StandardMaterial3D:
	var m := _material(Color.WHITE, 0.7)
	m.albedo_texture = load(path)
	if alpha:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m

## A painted quad on both faces of a door leaf (`y` is relative to the leaf centre).
func _door_face(body: Node3D, width: float, height: float, y: float, thickness: float, material: Material, x := 0.0, back_material: Material = null) -> void:
	for face in [1.0, -1.0]:
		var quad := QuadMesh.new()
		quad.size = Vector2(width, height)
		var mi := MeshInstance3D.new()
		mi.mesh = quad
		mi.material_override = material if face > 0.0 or back_material == null else back_material
		mi.position = Vector3(x, y, face * (thickness / 2.0 + 0.0012))
		if face < 0.0:
			mi.rotation.y = PI
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(mi)

## A chunky hardware box through the leaf so it reads from both sides.
func _hardware(body: Node3D, size: Vector3, pos: Vector3, material: Material) -> void:
	_bar(body, size, pos, material)

## Three hinge knuckles on the hinge edge of a leaf.
func _hinges(body: Node3D, leaf_w: float, hinge_x: float, thickness: float, material: Material) -> void:
	for y in [-0.8, 0.0, 0.8]:
		_bar(body, Vector3(0.035, 0.12, thickness + 0.03), Vector3(hinge_x, y, 0), material)

## Non-colliding casing around a door opening, in the door's own frame.
func _casing(door: Door, span: float, height: float, depth: float, material: Material) -> void:
	for x in [-span / 2.0 - 0.035, span / 2.0 + 0.035]:
		_bar(door, Vector3(0.07, height, depth), Vector3(x, height / 2.0, 0), material)
	_bar(door, Vector3(span + 0.14, 0.07, depth), Vector3(0, height + 0.035, 0), material)

func _build_front_door() -> void:
	var glass := _material(Color(0.4, 0.5, 0.46, 0.12), 0.25, 0.0, true)
	front_door = Door.new().setup(world, "front door", FRONT_CENTRE, 0.0, Vector3(0.82, 2.16, 0.045), true, glass, true)
	front_door.customers_open_it = true
	front_door.lock_gate = func():
		return "" if game.director != null and game.director.step >= StoryDirector.Step.ANOMALY else "We're open until midnight."
	var frame := _material(Color(0.13, 0.14, 0.15), 0.4, 0.7)
	var alu := _texture_material("res://assets/materials/door_alu.png")
	var decal := _texture_material("res://assets/materials/door_decal.png", true)
	var push_decal := _texture_material("res://assets/materials/door_decal_push.png", true)
	var brass := _material(Color(0.7, 0.58, 0.26), 0.3, 0.85)
	var leaf_w := 0.82
	for leaf in front_door.leaves:
		var body: StaticBody3D = leaf.body
		var toward: float = leaf.dir
		_bar(body, Vector3(leaf_w, 0.14, 0.07), Vector3(0, 1.0, 0), frame)
		_bar(body, Vector3(leaf_w, 0.08, 0.06), Vector3(0, 0.05, 0), frame)
		for x in [-leaf_w * 0.5 + 0.045, leaf_w * 0.5 - 0.045]:
			_bar(body, Vector3(0.09, 2.16, 0.07), Vector3(x, 0, 0), frame)
		_door_face(body, leaf_w - 0.12, 0.34, -0.9, 0.07, alu)
		_bar(body, Vector3(leaf_w, 0.05, 0.075), Vector3(0, -0.72, 0), frame)
		_door_face(body, leaf_w - 0.14, 0.12, 0.3, 0.045, push_decal, 0.0, decal)
		# vertical pull bar on the free edge, standing off both faces on brass posts
		var bar_x: float = toward * (leaf_w * 0.5 - 0.1)
		_bar(body, Vector3(0.035, 0.75, 0.035), Vector3(bar_x, 0.0, 0.085), brass)
		_bar(body, Vector3(0.035, 0.75, 0.035), Vector3(bar_x, 0.0, -0.085), brass)
		for y in [-0.3, 0.3]:
			_bar(body, Vector3(0.03, 0.03, 0.17), Vector3(bar_x, y, 0), brass)
	var right_body: StaticBody3D = front_door.leaves[1].body
	var bolt := Door.DoorBolt.new()
	bolt.door = front_door
	bolt.position = Vector3(-0.29, -0.075, 0.0)
	var grab := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.14, 0.14, 0.14)
	grab.shape = box
	bolt.add_child(grab)
	right_body.add_child(bolt)
	_bar(right_body, Vector3(0.06, 0.12, 0.045), Vector3(-0.29, -0.075, 0.04), _material(Color(0.7, 0.58, 0.26), 0.3, 0.85))
	_casing(front_door, 1.64, 2.2, 0.16, frame)

func _build_office_door() -> void:
	var wood := _material(Color(0.36, 0.25, 0.16), 0.8)
	office_door = Door.new().setup(world, "office door", Vector3(5.0, 0.0, -4.3), -PI / 2.0, Vector3(1.1, 2.16, 0.045), false, wood)
	var body: StaticBody3D = office_door.leaves[0].body
	var brass := _material(Color(0.7, 0.58, 0.26), 0.3, 0.85)
	var dark := _material(Color(0.12, 0.1, 0.09), 0.5, 0.5)
	_door_face(body, 1.1, 2.16, 0.0, 0.045, _texture_material("res://assets/materials/door_wood.png"))
	var bolt := Door.DoorBolt.new()
	bolt.door = office_door
	bolt.position = Vector3(-0.38, -0.075, -0.06)
	var grab := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.14, 0.14, 0.08)
	grab.shape = box
	bolt.add_child(grab)
	body.add_child(bolt)
	_bar(body, Vector3(0.06, 0.12, 0.03), Vector3(-0.38, -0.075, -0.045), brass)
	# lever handle and backplate on the latch edge, through the leaf
	_hardware(body, Vector3(0.05, 0.2, 0.06), Vector3(0.44, -0.05, 0), brass)
	_hardware(body, Vector3(0.17, 0.035, 0.085), Vector3(0.37, -0.05, 0), brass)
	_hinges(body, 1.1, -0.545, 0.045, dark)
	var nameplate := _material(Color(0.82, 0.78, 0.6), 0.5)
	_bar(body, Vector3(0.22, 0.07, 0.006), Vector3(0.0, 0.62, 0.0255), nameplate)
	var plate_text := Label3D.new()
	plate_text.text = "OFFICE"
	plate_text.font_size = 20
	plate_text.pixel_size = 0.0022
	plate_text.modulate = Color(0.16, 0.12, 0.08)
	plate_text.position = Vector3(0, 0.62, 0.0295)
	plate_text.double_sided = false
	body.add_child(plate_text)
	_casing(office_door, 1.1, 2.18, 0.17, _material(Color(0.28, 0.19, 0.12), 0.8))

func _build_rear_door() -> void:
	var steel := _material(Color(0.2, 0.26, 0.29), 0.55, 0.3)
	rear_door = Door.new().setup(world, "rear door", REAR_CENTRE, 0.0, Vector3(1.0, 2.16, 0.07), false, steel)
	var body: StaticBody3D = rear_door.leaves[0].body
	var hardware := _material(Color(0.14, 0.15, 0.16), 0.4, 0.7)
	_door_face(body, 1.0, 2.16, 0.0, 0.07, _texture_material("res://assets/materials/door_steel.png"))
	_bar(body, Vector3(0.72, 0.05, 0.05), Vector3(0.0, -0.075, 0.075), hardware)
	for x in [-0.34, 0.34]:
		_bar(body, Vector3(0.05, 0.05, 0.06), Vector3(x, -0.075, 0.05), hardware)
	_hinges(body, 1.0, -0.495, 0.07, hardware)
	var exit_sign := _material(Color(0.75, 0.08, 0.06), 0.4)
	exit_sign.emission_enabled = true
	exit_sign.emission = Color(0.9, 0.1, 0.07)
	exit_sign.emission_energy_multiplier = 0.9
	_bar(rear_door, Vector3(0.42, 0.16, 0.06), Vector3(0, 2.46, 0.1), exit_sign)
	var exit_text := Label3D.new()
	exit_text.text = "EXIT"
	exit_text.font_size = 36
	exit_text.pixel_size = 0.0032
	exit_text.modulate = Color(1, 0.9, 0.85)
	exit_text.shaded = false
	exit_text.position = Vector3(0, 2.46, 0.133)
	exit_text.double_sided = false
	rear_door.add_child(exit_text)
	var sign_label := Label3D.new()
	sign_label.text = "KEEP REAR DOOR CLOSED"
	sign_label.font_size = 23
	sign_label.pixel_size = 0.003
	sign_label.modulate = Color(0.8, 0.78, 0.64)
	sign_label.position = Vector3(0, 0.65, 0.037)
	sign_label.double_sided = false
	body.add_child(sign_label)
	# The latch and key from the M3 chore ride on the door leaf.
	for part in game.shift.latch_parts:
		part.reparent(body, true)

## The back step: a pad to stand on and one flat bulb, so the doorway is not a hole into the void.
func _build_stoop() -> void:
	var pad := StaticBody3D.new()
	pad.name = "RearStoop"
	pad.collision_layer = 1
	pad.position = Vector3(4.25, -0.11, -8.5)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(7.0, 0.22, 5.0)
	shape.shape = box
	pad.add_child(shape)
	_bar(pad, Vector3(7.0, 0.22, 5.0), Vector3.ZERO, _material(Color(0.2, 0.2, 0.2), 0.9))
	world.add_child(pad)
	var bulb := OmniLight3D.new()
	bulb.position = Vector3(4.25, 2.7, -6.7)
	bulb.light_color = Color(1.0, 0.84, 0.55)
	bulb.light_energy = 0.9
	bulb.omni_range = 5.0
	world.add_child(bulb)

# --- events the story can call ------------------------------------------------------------------

## Someone with a key opens the rear door for a moment and shuts it again.
func pulse_rear_door() -> void:
	rear_door.set_locked(false)
	rear_door.request_open()
	await get_tree().create_timer(1.6).timeout
	rear_door.request_close()

func spawn_intruder() -> Intruder:
	if is_instance_valid(intruder):
		return intruder
	return spawn_stalker()

## Leon on the hunt: same model as the rear intruder, but he walks the store on his own.
func spawn_stalker() -> Stalker:
	if is_instance_valid(intruder):
		intruder.queue_free()
	var profile := {"id": "leon_rear", "name": "Leon", "model": "vinrax", "outfit": "leon_overshirt", "cap": true, "route": {}}
	var stalker := Stalker.new()
	stalker.setup(game, profile)
	stalker.prepare(rear_door)
	stalker.office_door = office_door
	stalker._excused = true
	world.add_child(stalker)
	stalker.global_position = Intruder.OUTSIDE
	intruder = stalker
	return stalker
