class_name Clues
extends Node3D
## Physical evidence. Props exist from the start in their normal state; `activate()` changes them once.
signal clue_seen(clue_id: String)
const HOOK_BOARD := Vector3(5.075, 1.45, -3.1)
const ENVELOPE_NEAT := Vector3(8.35, 0.778, -5.1)
const ENVELOPE_MOVED := Vector3(7.45, 0.778, -5.12)
const PRINT_PATH := [Vector3(4.18, 0, -5.55), Vector3(4.38, 0, -5.0), Vector3(4.2, 0, -4.45), Vector3(4.4, 0, -3.9), Vector3(4.22, 0, -3.3), Vector3(4.4, 0, -2.7), Vector3(4.24, 0, -2.1), Vector3(4.4, 0, -1.5)]
var active := false
var seen := {}
var _spare_key: MeshInstance3D
var _envelope: Node3D
var _flap: MeshInstance3D
var _prints: Array[MeshInstance3D] = []
var _print_spot: ClueSpot
var _envelope_spot: ClueSpot

func build(world: Node3D) -> Clues:
	name = "Clues"
	world.add_child(self)
	_build_hooks()
	_build_envelope()
	_build_prints()
	return self

func _mat(color: Color, rough := 0.8, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metallic
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return m

func _lit_brass() -> StandardMaterial3D:
	var m := _mat(Color(0.85, 0.68, 0.26), 0.35, 0.7)
	m.emission_enabled = true
	m.emission = Color(0.55, 0.4, 0.1)
	m.emission_energy_multiplier = 0.5
	return m

func _mesh(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	parent.add_child(mi)
	return mi

func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b

func _spot(clue_id: String, size: Vector3, pos: Vector3, normal: Callable) -> ClueSpot:
	var spot := ClueSpot.new()
	spot.clue_id = clue_id
	spot.describe = normal
	spot.position = pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	spot.add_child(shape)
	spot.seen.connect(_on_seen)
	add_child(spot)
	return spot

func _on_seen(clue_id: String) -> void:
	if not active or seen.has(clue_id):
		return  # looking at things before the anomaly proves nothing
	seen[clue_id] = true
	clue_seen.emit(clue_id)

func _build_hooks() -> void:
	var board := Node3D.new()
	board.position = HOOK_BOARD
	board.rotation.y = PI / 2.0  # faces +x into the office
	add_child(board)
	_mesh(board, _box(Vector3(0.62, 0.34, 0.025)), _mat(Color(0.42, 0.3, 0.19), 0.9), Vector3.ZERO)
	var labels := ["REAR", "OFFICE", "FRIDGE", "SPARE"]
	for i in 4:
		var x := -0.22 + i * 0.147
		_mesh(board, _box(Vector3(0.012, 0.03, 0.03)), _mat(Color(0.7, 0.7, 0.68), 0.3, 0.9), Vector3(x, 0.05, 0.03))
		var tag := Label3D.new()
		tag.text = labels[i]
		tag.font_size = 22
		tag.pixel_size = 0.0007
		tag.modulate = Color(0.82, 0.78, 0.62)
		tag.position = Vector3(x, 0.135, 0.016)
		tag.outline_size = 0
		tag.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		board.add_child(tag)
		var key := _mesh(board, _box(Vector3(0.022, 0.07, 0.008)), _lit_brass(), Vector3(x, 0.0, 0.034))
		if i == 3:
			_spare_key = key
	_spot("spare_key", Vector3(0.5, 0.5, 0.7), HOOK_BOARD + Vector3(0.25, 0, 0), func():
		return "Key hooks. The SPARE hook is empty." if active else "Key hooks: REAR, OFFICE, FRIDGE, SPARE. All in their place.")

func _build_envelope() -> void:
	_envelope = Node3D.new()
	_envelope.position = ENVELOPE_NEAT
	add_child(_envelope)
	_mesh(_envelope, _box(Vector3(0.24, 0.006, 0.12)), _mat(Color(0.8, 0.74, 0.55), 0.9), Vector3.ZERO)
	var flap_pivot := Node3D.new()
	flap_pivot.position = Vector3(0, 0.004, -0.06)
	_envelope.add_child(flap_pivot)
	_flap = _mesh(flap_pivot, _box(Vector3(0.24, 0.003, 0.055)), _mat(Color(0.74, 0.68, 0.5), 0.9), Vector3(0, 0, 0.0275))
	var label := Label3D.new()
	label.text = "CASH DROP"
	label.font_size = 24
	label.pixel_size = 0.0006
	label.modulate = Color(0.25, 0.15, 0.12)
	label.rotation_degrees.x = -90.0
	label.position = Vector3(0, 0.0045, 0.02)
	label.outline_size = 0
	_envelope.add_child(label)
	_envelope_spot = _spot("cash_envelope", Vector3(0.3, 0.14, 0.2), ENVELOPE_NEAT + Vector3(0, 0.05, 0), func():
		return "The cash drop envelope. Moved. The flap has been peeled open." if active else "Cash drop envelope. Sealed. Dina wants it in the drawer by 11:55.")

func _build_prints() -> void:
	var texture := load("res://assets/story/boot_print.png") as Texture2D
	var wet := _mat(Color(1, 1, 1), 0.08)
	wet.albedo_texture = texture
	wet.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wet.metallic_specular = 1.0
	for i in PRINT_PATH.size():
		var quad := MeshInstance3D.new()
		var mesh := QuadMesh.new()
		mesh.size = Vector2(0.17, 0.3)
		quad.mesh = mesh
		quad.material_override = wet
		quad.rotation = Vector3(-PI / 2.0, 0.0 if i % 2 == 0 else PI, 0)
		quad.rotation.y = 0.1 if i % 2 == 0 else -0.1
		var p: Vector3 = PRINT_PATH[i]
		quad.position = Vector3(p.x, 0.006, p.z)
		quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		quad.visible = false
		add_child(quad)
		_prints.append(quad)
	_print_spot = _spot("boot_prints", Vector3(0.9, 0.12, 4.4), Vector3(4.3, 0.06, -3.55), func():
		return "Wet boot prints, heading from the rear door toward the stockroom.")
	_print_spot.enabled = false

## The anomaly: the hook empties, the envelope moves and is opened, wet prints appear.
func activate() -> bool:
	if active:
		return false
	active = true
	_spare_key.visible = false
	_envelope.position = ENVELOPE_MOVED
	_envelope.rotation.y = 0.55
	_envelope_spot.position = ENVELOPE_MOVED + Vector3(0, 0.05, 0)
	_flap.get_parent().rotation.x = -0.75
	for quad in _prints:
		quad.visible = true
	_print_spot.enabled = true
	return true

## Back to the normal state (checkpoint retry, tests). Clues seen so far are forgotten.
func reset() -> void:
	active = false
	seen.clear()
	_spare_key.visible = true
	_envelope.position = ENVELOPE_NEAT
	_envelope.rotation.y = 0.0
	_envelope_spot.position = ENVELOPE_NEAT + Vector3(0, 0.05, 0)
	_flap.get_parent().rotation.x = 0.0
	for quad in _prints:
		quad.visible = false
	_print_spot.enabled = false

class ClueSpot extends Interactable:
	signal seen(clue_id: String)
	var clue_id := ""
	var describe: Callable
	func _init() -> void:
		super()
		display_name = "this"
		verb = "Examine"
	func prompt_text(actor: Node) -> String:
		return "Examine" if can_interact(actor) else ""
	func interact(actor: Node) -> void:
		var text: String = describe.call()
		seen.emit(clue_id)
		if actor != null and actor.has_signal("message"):
			actor.message.emit(text)
		interacted.emit(actor)
	func inspect(actor: Node) -> String:
		seen.emit(clue_id)
		inspected.emit(actor)
		return describe.call()
