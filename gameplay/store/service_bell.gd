class_name ServiceBell
extends Interactable
## Counter bell. Purely tactile: it rings and nothing else.
signal rung
var _sound: AudioStreamPlayer3D

func _init() -> void:
	super()
	display_name = "service bell"
	verb = "Ring"
	description = "A dented chrome bell. Customers still slap it even when you're standing right there."
	name = "ServiceBell"

func build(parent: Node3D, pos: Vector3) -> ServiceBell:
	position = pos
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.07
	cyl.height = 0.08
	shape.shape = cyl
	shape.position.y = 0.04
	add_child(shape)
	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.07
	base_mesh.bottom_radius = 0.075
	base_mesh.height = 0.012
	base.mesh = base_mesh
	base.material_override = _metal(Color(0.05, 0.05, 0.05), 0.6, 0.3)
	base.position.y = 0.006
	add_child(base)
	var dome := MeshInstance3D.new()
	var dome_mesh := SphereMesh.new()
	dome_mesh.radius = 0.06
	dome_mesh.height = 0.12
	dome_mesh.is_hemisphere = true
	dome.mesh = dome_mesh
	dome.material_override = _metal(Color(0.72, 0.72, 0.7), 0.25, 0.9)
	dome.position.y = 0.014
	add_child(dome)
	var button := MeshInstance3D.new()
	var button_mesh := CylinderMesh.new()
	button_mesh.top_radius = 0.009
	button_mesh.bottom_radius = 0.012
	button_mesh.height = 0.02
	button.mesh = button_mesh
	button.material_override = _metal(Color(0.8, 0.78, 0.7), 0.3, 0.9)
	button.position.y = 0.083
	add_child(button)
	_sound = Tone.player(Tone.stream(1650.0, 900, 0.45, 0.28), Vector3(0, 0.08, 0), 3.0)
	add_child(_sound)
	parent.add_child(self)
	return self

func _metal(color: Color, rough: float, metallic: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metallic
	return m

func interact(actor: Node) -> void:
	_sound.play()
	rung.emit()
	interacted.emit(actor)

func _exit_tree() -> void:
	if _sound:
		_sound.stop()
		_sound.stream = null
