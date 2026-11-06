class_name InteriorDressing
extends Node3D
## Set dressing taken from the art references: wall stripe, cork board, convex mirror, notices, CLOSED sign.
const RED := Color(0.5, 0.07, 0.06)
const PAPER := Color(0.78, 0.74, 0.62)

func _ready() -> void:
	name = "InteriorDressing"
	_build_stripe()
	_build_cork_board()
	_build_mirror()
	_build_notices()
	_build_closed_sign()
	_build_counter_laminate()

func _mat(color: Color, rough := 0.85, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metallic
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return m

func _box(size: Vector3, pos: Vector3, material: Material, rot_y := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation.y = rot_y
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

func _text(value: String, pos: Vector3, size: int, pixel: float, color: Color, rot_y := 0.0) -> Label3D:
	var label := Label3D.new()
	label.text = value
	label.position = pos
	label.rotation.y = rot_y
	label.font_size = size
	label.pixel_size = pixel
	label.modulate = color
	label.outline_size = 0
	label.double_sided = false
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	add_child(label)
	return label

func _build_stripe() -> void:
	var red := _mat(RED, 0.75)
	_box(Vector3(0.03, 0.13, 11.7), Vector3(-8.875, 2.8, 0.0), red)
	_box(Vector3(12.3, 0.13, 0.03), Vector3(-2.7, 2.8, -5.875), red)

func _build_cork_board() -> void:
	var origin := Vector3(-8.865, 1.62, -1.8)
	_box(Vector3(0.05, 0.78, 1.15), origin, _mat(Color(0.25, 0.17, 0.1), 0.7))
	_box(Vector3(0.03, 0.68, 1.05), origin + Vector3(0.012, 0, 0), _mat(Color(0.52, 0.38, 0.24), 0.95))
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	for i in 7:
		var note := _box(Vector3(0.012, rng.randf_range(0.12, 0.22), rng.randf_range(0.1, 0.2)), origin + Vector3(0.03, rng.randf_range(-0.22, 0.22), rng.randf_range(-0.4, 0.4)), _mat(PAPER.lerp(Color(0.85, 0.8, 0.55), rng.randf()), 0.9))
		note.rotation.x = rng.randf_range(-0.15, 0.15)

func _build_mirror() -> void:
	var pos := Vector3(3.3, 2.72, -5.0)
	var rim := MeshInstance3D.new()
	var rim_mesh := CylinderMesh.new()
	rim_mesh.top_radius = 0.31
	rim_mesh.bottom_radius = 0.31
	rim_mesh.height = 0.04
	rim.mesh = rim_mesh
	rim.material_override = _mat(Color(0.08, 0.08, 0.08), 0.5, 0.3)
	rim.rotation = Vector3(PI / 2.0, 0, 0)
	var mirror := MeshInstance3D.new()
	var dome := SphereMesh.new()
	dome.radius = 0.28
	dome.height = 0.14
	mirror.mesh = dome
	mirror.material_override = _mat(Color(0.82, 0.86, 0.9), 0.04, 1.0)
	mirror.rotation = Vector3(PI / 2.0, 0, 0)
	mirror.scale = Vector3(1, 0.7, 1)
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = -PI / 4.0  # corner mirror angled across the sales floor
	holder.add_child(rim)
	mirror.position.y = 0.0
	mirror.position.z = 0.0
	holder.add_child(mirror)
	add_child(holder)
	# Bracket back to the wall.
	_box(Vector3(0.06, 0.06, 0.3), pos + Vector3(0.12, 0, -0.1), _mat(Color(0.08, 0.08, 0.08), 0.6, 0.5), -PI / 4.0)

func _build_notices() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for x in [-1.55, -1.25]:
		var sheet := _box(Vector3(0.24, 0.32, 0.004), Vector3(x, rng.randf_range(1.45, 1.8), 5.935), _mat(PAPER, 0.9))
		sheet.rotation.z = rng.randf_range(-0.06, 0.06)
	_text("NO PUBLIC\nRESTROOM", Vector3(-1.25, 1.58, 5.932), 22, 0.0007, Color(0.2, 0.15, 0.1), PI)

func _build_closed_sign() -> void:
	var pos := Vector3(0.45, 1.55, 5.93)
	_box(Vector3(0.012, 0.4, 0.012), pos + Vector3(-0.09, 0.3, 0), _mat(Color(0.35, 0.28, 0.2)))
	_box(Vector3(0.012, 0.4, 0.012), pos + Vector3(0.09, 0.3, 0), _mat(Color(0.35, 0.28, 0.2)))
	_box(Vector3(0.34, 0.2, 0.016), pos, _mat(Color(0.74, 0.66, 0.5), 0.85))
	# The paper faces the lot, leaving the readable side turned away from the clerk.
	_text("CLOSED", pos + Vector3(0, 0, -0.01), 54, 0.0017, Color(0.2, 0.15, 0.1), 0.0)

## A curling paper sheet on the laminate counter top.
func _build_counter_laminate() -> void:
	var sheet := _box(Vector3(0.28, 0.002, 0.2), Vector3(-7.15, 0.96, 3.98), _mat(Color(0.8, 0.76, 0.66), 0.9))
	sheet.rotation.y = 0.12
