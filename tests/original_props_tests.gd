extends SceneTree
const PSX = preload("res://assets/models/psx_pack/asset_loader.gd")

func _initialize() -> void:
	var failures := 0
	var total := 0
	var manifest: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/psx_pack/manifest.json"))
	for entry in manifest:
		var model := PSX.make(str(entry.name))
		if model == null:
			failures += 1
			continue
		var tris := 0
		for child in model.find_children("*","MeshInstance3D",true,false):
			var mesh := child as MeshInstance3D
			for surface in mesh.mesh.get_surface_count():
				var arrays := mesh.mesh.surface_get_arrays(surface)
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				tris += int((indices.size() if not indices.is_empty() else vertices.size()) / 3.0)
				var material := mesh.get_active_material(surface) as BaseMaterial3D
				if material == null or material.albedo_texture == null:
					failures += 1
		if tris != int(entry.triangles):
			printerr("Triangle count mismatch: ",entry.name," ",tris," expected ",entry.triangles)
			failures += 1
		total += tris
		for node_name in entry.nodes:
			if model.find_child(str(node_name),true,false) == null:
				printerr("Missing named mesh: ",entry.name," ",node_name)
				failures += 1
		model.free()
	print("PSX ASSET TESTS COMPLETE: ",manifest.size()," GLBs, ",total," triangles, failures=",failures)
	quit(1 if failures else 0)
