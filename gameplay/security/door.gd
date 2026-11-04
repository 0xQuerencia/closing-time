class_name Door
extends Node3D
## A hinged door. One or two leaves swing on pivots, collide while they are in the way, and can be locked.
## `contact_broken` / `contact_made` are the reed-switch events a door sensor listens to.
signal contact_broken
signal contact_made
signal lock_changed(locked: bool)
const SWING_SECONDS := 0.8
const OPEN_ANGLE := deg_to_rad(98.0)
const CLOSED_EPSILON := 0.02
var door_name := "door"
var locked := false
var is_open := false  # where the door is heading, not where it is
var angle := 0.0
var size := Vector3(1.0, 2.1, 0.07)
var double := false
var customers_open_it := false
var lock_gate := Callable()  # returns a reason String when locking is not allowed yet
var handle: DoorHandle
var leaves: Array[Dictionary] = []  # {pivot, body, dir}
var _held_open := false  # the player opened it: customers' auto-close leaves it alone
var _close_timer := 0.0
var _contact_open := false
var _sound_open: AudioStreamPlayer3D
var _sound_shut: AudioStreamPlayer3D
var _sound_lock: AudioStreamPlayer3D

## `centre` is the middle of the opening at floor level; the leaf swings toward local -Z.
func setup(world: Node3D, label: String, centre: Vector3, yaw: float, leaf_size: Vector3, is_double: bool, material: Material, glass := false) -> Door:
	door_name = label
	name = "Door_" + label.replace(" ", "")
	size = leaf_size
	double = is_double
	position = centre
	rotation.y = yaw
	var span := leaf_size.x * (2.0 if is_double else 1.0)
	var sides: Array[float] = [-1.0]
	if is_double:
		sides.append(1.0)
	for side: float in sides:
		var pivot := Node3D.new()
		pivot.name = "Hinge" + ("L" if side < 0.0 else "R")
		pivot.position = Vector3(side * span * 0.5, 0, 0)
		add_child(pivot)
		var toward_centre: float = -side
		var middle := Vector3(toward_centre * leaf_size.x * 0.5, leaf_size.y * 0.5, 0)
		var body := StaticBody3D.new()
		body.name = "Leaf"
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = middle
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = leaf_size
		shape.shape = box
		body.add_child(shape)
		pivot.add_child(body)
		var mesh := MeshInstance3D.new()
		var slab := BoxMesh.new()
		slab.size = leaf_size
		mesh.mesh = slab
		mesh.material_override = material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if glass else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		body.add_child(mesh)
		handle = DoorHandle.new()
		handle.door = self
		handle.position = middle
		var grab := CollisionShape3D.new()
		var grab_box := BoxShape3D.new()
		grab_box.size = Vector3(leaf_size.x * 0.96, leaf_size.y * 0.96, leaf_size.z + 0.05)
		grab.shape = grab_box
		handle.add_child(grab)
		pivot.add_child(handle)
		leaves.append({"pivot": pivot, "body": body, "dir": -side})
	_build_sounds()
	world.add_child(self)
	return self

func _build_sounds() -> void:
	_sound_open = Tone.player(Tone.stream(96.0, 260, 0.6, 0.45), Vector3(0, 1.0, 0), 5.0)
	_sound_shut = Tone.player(Tone.stream(70.0, 200, 0.9, 0.55), Vector3(0, 1.0, 0), 6.0)
	_sound_lock = Tone.player(Tone.stream(1500.0, 70, 1.3, 0.22), Vector3(0, 1.1, 0), 4.0)
	for s in [_sound_open, _sound_shut, _sound_lock]:
		s.max_distance = 18.0
		add_child(s)

func _exit_tree() -> void:
	for s in [_sound_open, _sound_shut, _sound_lock]:
		if s:
			s.stop()
			s.stream = null

# --- state --------------------------------------------------------------------------------------

func is_closed() -> bool:
	return angle <= CLOSED_EPSILON and not is_open

func is_fully_open() -> bool:
	return is_open and absf(angle - OPEN_ANGLE) < CLOSED_EPSILON

## Why the door cannot be opened right now, or "".
func open_blocked_reason() -> String:
	return "Locked." if locked else ""

func request_open(_actor: Node = null) -> bool:
	if locked:
		return false
	_set_target(true)
	return true

func request_close() -> void:
	_set_target(false)

func toggle(actor: Node = null) -> bool:
	if is_open:
		_held_open = false
		_set_target(false)
		return true
	_held_open = true
	return request_open(actor)

func set_locked(value: bool, quiet := false) -> void:
	if locked == value:
		return
	locked = value
	if not quiet:
		_sound_lock.play()
	lock_changed.emit(locked)

## Why the player cannot lock this door yet, or "".
func lock_blocked_reason() -> String:
	if is_open:
		return "Close it first."
	if lock_gate.is_valid():
		return lock_gate.call()
	return ""

## Jump straight to a state (tests, checkpoint reset). Emits the same sensor events.
func snap(open: bool) -> void:
	_set_target(open)
	angle = OPEN_ANGLE if open else 0.0
	_apply_angle()
	_update_contact()

func _set_target(open: bool) -> void:
	if is_open == open:
		return
	is_open = open
	if open:
		_sound_open.play()
	_close_timer = 0.0

func _process(delta: float) -> void:
	var goal := OPEN_ANGLE if is_open else 0.0
	if not is_equal_approx(angle, goal):
		var before := angle
		angle = move_toward(angle, goal, delta * OPEN_ANGLE / SWING_SECONDS)
		_apply_angle()
		if before > 0.0 and angle <= 0.0 and not is_open:
			_sound_shut.play()
	_update_contact()

func _apply_angle() -> void:
	for leaf in leaves:
		(leaf.pivot as Node3D).rotation.y = angle * leaf.dir

func _update_contact() -> void:
	var broken := angle > CLOSED_EPSILON
	if broken and not _contact_open:
		_contact_open = true
		contact_broken.emit()
	elif not broken and _contact_open:
		_contact_open = false
		contact_made.emit()

func _physics_process(delta: float) -> void:
	if not customers_open_it:
		return
	var near := _customer_near(2.3)
	if near and not locked:
		_close_timer = 0.0
		if not is_open:
			_set_target(true)
		return
	if is_open and not _held_open and not near:
		_close_timer += delta
		if _close_timer > 1.2 and not _player_in_doorway():
			_set_target(false)

func _customer_near(radius: float) -> bool:
	for npc in get_tree().get_nodes_in_group("customers"):
		var flat: Vector3 = (npc as Node3D).global_position - global_position
		flat.y = 0.0
		if flat.length() < radius:
			return true
	return false

func _player_in_doorway() -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return false
	var local := to_local(player.global_position)
	return absf(local.z) < 0.7 and absf(local.x) < size.x * (2.0 if double else 1.0) * 0.5 + 0.2

# --- interaction --------------------------------------------------------------------------------

class DoorHandle extends Interactable:
	var door: Door
	func _init() -> void:
		super()
		name = "Handle"
	func can_interact(_actor: Node) -> bool:
		return enabled and (door.is_open or not door.locked)
	func blocked_reason(_actor: Node) -> String:
		return "The %s is locked." % door.door_name if door.locked else ""
	func prompt_text(actor: Node) -> String:
		if not can_interact(actor):
			return ""
		return ("Close the " if door.is_open else "Open the ") + door.door_name
	func interact(actor: Node) -> void:
		door.toggle(actor)
		interacted.emit(actor)
	func inspect(actor: Node) -> String:
		inspected.emit(actor)
		if door.locked:
			return "The %s is locked." % door.door_name
		return "The %s is %s." % [door.door_name, "open" if door.is_open else "closed"]

## A deadbolt the player can turn from the inside. The rear door uses the M3 latch-and-key instead.
class DoorBolt extends Interactable:
	var door: Door
	func _init() -> void:
		super()
		name = "Bolt"
		display_name = "deadbolt"
	func can_interact(_actor: Node) -> bool:
		return enabled and (door.locked or door.lock_blocked_reason() == "")
	func blocked_reason(_actor: Node) -> String:
		return door.lock_blocked_reason()
	func prompt_text(actor: Node) -> String:
		if not can_interact(actor):
			return ""
		return "Unlock the " + door.door_name if door.locked else "Lock the " + door.door_name
	func interact(actor: Node) -> void:
		door.set_locked(not door.locked)
		interacted.emit(actor)
	func inspect(actor: Node) -> String:
		inspected.emit(actor)
		return "A deadbolt. It's %s." % ("thrown" if door.locked else "open")
