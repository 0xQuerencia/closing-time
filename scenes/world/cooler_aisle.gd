extends Node3D
## Displays the authored GLB and batches repeated facings by shared mesh.
const SCENE := preload("res://assets/models/cooler_aisle.glb")
const ATLAS := preload("res://assets/models/cooler_atlas.png")

var bottle_mesh: Mesh
var _tube_material: StandardMaterial3D
var _tube_energy := 0.0

func _ready() -> void:
	name = "CoolerAisle"
	var model := SCENE.instantiate()
	for part in model.find_children("*", "MeshInstance3D", true, false):
		var material := part.mesh.surface_get_material(0) as StandardMaterial3D
		material.albedo_texture = ATLAS
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		part.add_to_group("authored_materials")
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if material.resource_name == "CoolerSafetyGlass":
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		elif material.resource_name == "CoolerFluorescent":
			_tube_material = material.duplicate() as StandardMaterial3D
			_tube_material.emission_texture = ATLAS
			_tube_energy = _tube_material.emission_energy_multiplier
			part.set_surface_override_material(0, _tube_material)
	var stock := model.get_node("DisplayStock")
	bottle_mesh = stock.get_node("BirchSpring").mesh
	for group in stock.get_children():
		if group is MeshInstance3D:
			continue
		var poses: Array[Transform3D] = []
		var mesh: Mesh = group.get_child(0).mesh
		for part in group.get_children():
			poses.append(part.transform)
		add_child(batch(group.name, mesh, poses))
	stock.free()
	add_child(model)

func bind_power(power: PowerGrid) -> void:
	var refresh := func() -> void:
		_tube_material.emission_energy_multiplier = _tube_energy if power.powered("lights") else 0.0
	power.changed.connect(refresh)
	refresh.call()

static func batch(label: String, mesh: Mesh, poses: Array[Transform3D]) -> MultiMeshInstance3D:
	var layout := MultiMesh.new()
	layout.transform_format = MultiMesh.TRANSFORM_3D
	layout.mesh = mesh
	layout.instance_count = poses.size()
	for index in poses.size():
		layout.set_instance_transform(index, poses[index])
	var instance := MultiMeshInstance3D.new()
	instance.name = label
	instance.multimesh = layout
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance
