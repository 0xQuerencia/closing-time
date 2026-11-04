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

func _build_front_door() -> void:
	var glass := _material(Color(0.4, 0.5, 0.46, 0.12), 0.25, 0.0, true)
	front_door = Door.new().setup(world, "front door", FRONT_CENTRE, 0.0, Vector3(0.82, 2.16, 0.045), true, glass, true)
	front_door.customers_open_it = true
	front_door.lock_gate = func():
		return "" if game.director != null and game.director.step >= StoryDirector.Step.ANOMALY else "We're open until midnight."
	var frame := _material(Color(0.1, 0.11, 0.12), 0.45, 0.6)
	var leaf_w := 0.82
	for leaf in front_door.leaves:
		var body: StaticBody3D = leaf.body
		for y in [-1.04, 1.04]:
			_bar(body, Vector3(leaf_w, 0.07, 0.06), Vector3(0, y, 0), frame)
		for x in [-leaf_w * 0.5 + 0.03, leaf_w * 0.5 - 0.03]:
			_bar(body, Vector3(0.06, 2.16, 0.06), Vector3(x, 0, 0), frame)
		var toward: float = leaf.dir
		_bar(body, Vector3(0.03, 0.4, 0.03), Vector3(toward * leaf_w * 0.5 * -0.8, 0.0, 0.05), frame)
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
	_bar(right_body, Vector3(0.05, 0.12, 0.04), Vector3(-0.29, -0.075, 0.035), _material(Color(0.62, 0.5, 0.2), 0.35, 0.8))

func _build_rear_door() -> void:
	var steel := _material(Color(0.2, 0.26, 0.29), 0.55, 0.3)
	rear_door = Door.new().setup(world, "rear door", REAR_CENTRE, 0.0, Vector3(1.0, 2.16, 0.07), false, steel)
	var body: StaticBody3D = rear_door.leaves[0].body
	_bar(body, Vector3(0.72, 0.045, 0.05), Vector3(0.0, -0.075, 0.06), _material(Color(0.14, 0.15, 0.16), 0.4, 0.7))
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
	var profile := {"id": "leon_rear", "name": "Leon", "model": "vinrax", "outfit": "leon_overshirt", "cap": true, "route": {}}
	intruder = Intruder.new()
	intruder.setup(game, profile)
	intruder.prepare(rear_door)
	intruder._excused = true
	world.add_child(intruder)
	intruder.global_position = Intruder.OUTSIDE
	return intruder
