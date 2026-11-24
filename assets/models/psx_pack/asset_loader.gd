extends RefCounted

const ROOT := "res://assets/models/psx_pack/"

static func make(id: String) -> Node3D:
	var packed := load(ROOT + id + ".glb") as PackedScene
	if packed == null:
		push_error("Missing PSX asset: " + id)
		return null
	var model := packed.instantiate() as Node3D
	model.name = id
	model.set_meta("psx_asset",id)
	for child in model.find_children("*","MeshInstance3D",true,false):
		var mesh := child as MeshInstance3D
		if mesh.mesh == null:
			continue
		for i in mesh.mesh.get_surface_count():
			var source := mesh.get_active_material(i) as BaseMaterial3D
			if source != null:
				source.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	return model

static func place(parent: Node, id: String, at: Vector3, yaw: float = 0.0, scale_by: Vector3 = Vector3.ONE) -> Node3D:
	var model := make(id)
	if model != null:
		model.position = at
		model.rotation.y = yaw
		model.scale = scale_by
		parent.add_child(model)
	return model

static func hide_meshes(root: Node) -> void:
	for child in root.find_children("*","MeshInstance3D",true,false):
		(child as MeshInstance3D).hide()

static func mesh_and_material(id: String) -> Dictionary:
	var model := make(id)
	if model == null:
		return {}
	var meshes := model.find_children("*","MeshInstance3D",true,false)
	var result := {}
	if not meshes.is_empty():
		var body := meshes[0] as MeshInstance3D
		result = {"mesh":body.mesh,"material":body.get_active_material(0)}
	model.free()
	return result
