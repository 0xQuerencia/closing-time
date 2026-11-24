extends RefCounted
## The legacy retail GLB is batched into one mesh. Remove only triangles within
## the known fixture regions, keeping endcaps, floor, surrounding props and collisions.
const PSX = preload("res://assets/models/psx_pack/asset_loader.gd")

static func _regions() -> Array[AABB]:
	var regions: Array[AABB] = [AABB(Vector3(-8.22,-.05,3.72),Vector3(4.44,1.14,1.12))]
	for x in [-6.0,-3.0,0.0]:
		regions.append(AABB(Vector3(x-.52,-.05,-3.42),Vector3(1.04,1.96,5.03)))
	for i in range(6):
		var x := -7.1 + i*1.57
		regions.append(AABB(Vector3(x-.78,-.05,-5.96),Vector3(1.56,2.51,1.31)))
	return regions

static func replace(world: Node3D, retail: Node3D) -> bool:
	var candidates := retail.find_children("*","MeshInstance3D",true,false)
	if retail is MeshInstance3D:
		candidates.push_front(retail)
	if candidates.size() != 1:
		push_warning("PSX retail replacement expects the known batched retail mesh")
		return false
	var instance := candidates[0] as MeshInstance3D
	var mesh := instance.mesh as ArrayMesh
	if mesh == null:
		return false
	var regions := _regions()
	var removed := PackedInt32Array()
	removed.resize(regions.size())
	var replacement := ArrayMesh.new()
	for surface in mesh.get_surface_count():
		if mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
			return false
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var source_indices := PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] != null:
			source_indices = arrays[Mesh.ARRAY_INDEX]
		if source_indices.is_empty():
			source_indices.resize(vertices.size())
			for i in vertices.size():
				source_indices[i] = i
		var kept := PackedInt32Array()
		for i in range(0,source_indices.size(),3):
			var ia := source_indices[i]
			var ib := source_indices[i+1]
			var ic := source_indices[i+2]
			var center := world.to_local(instance.to_global((vertices[ia]+vertices[ib]+vertices[ic])/3.0))
			var region := -1
			for j in regions.size():
				if regions[j].has_point(center):
					region = j
					break
			if region >= 0:
				removed[region] += 1
			else:
				kept.append(ia)
				kept.append(ib)
				kept.append(ic)
		if kept.is_empty():
			continue
		arrays[Mesh.ARRAY_INDEX] = kept
		replacement.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		replacement.surface_set_material(replacement.get_surface_count()-1,instance.get_active_material(surface))
	for count in removed:
		if count == 0:
			push_warning("PSX retail replacement skipped: unexpected fixture bounds")
			return false
	if replacement.get_surface_count() == 0:
		return false
	instance.mesh = replacement
	instance.material_override = null
	for surface in instance.get_surface_override_material_count():
		instance.set_surface_override_material(surface,null)
	PSX.place(world,"counter",Vector3(-6,0,4.25),0,Vector3(1.592,1.029,1.129))
	for x in [-6.0,-3.0,0.0]:
		for i in range(4):
			PSX.place(world,"shelf",Vector3(x,0,-2.7375+i*1.225),PI/2,Vector3(.969,1,1.264))
	for i in range(6):
		PSX.place(world,"cooler",Vector3(-7.1+i*1.57,0,-5.31),0,Vector3(.85,1.125,1.6))
	world.set_meta("psx_retail_replaced",true)
	print("PSX RETAIL REPLACED: triangles removed per fixture ",removed)
	return true
