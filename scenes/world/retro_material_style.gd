extends RefCounted
## Applies mipmapped filtering to imported and procedural GLB surfaces.
## The method name is retained for existing scene and gameplay callers.

static func apply_nearest_filter(root: Node) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.material_override is BaseMaterial3D:
			var override := (mesh_instance.material_override as BaseMaterial3D).duplicate() as BaseMaterial3D
			override.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			mesh_instance.material_override = override
			continue
		if mesh_instance.mesh == null:
			continue
		for surface in mesh_instance.mesh.get_surface_count():
			var surface_material := mesh_instance.get_surface_override_material(surface)
			if surface_material == null:
				surface_material = mesh_instance.mesh.surface_get_material(surface)
			if surface_material is BaseMaterial3D:
				var styled := (surface_material as BaseMaterial3D).duplicate() as BaseMaterial3D
				styled.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
				mesh_instance.set_surface_override_material(surface, styled)
