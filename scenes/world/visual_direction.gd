extends Node
## Shared material treatment for world props and late-spawned characters.
## Cache duplicates to preserve batching; do not touch UI, LCD or CCTV shaders.
const RetroMaterials := preload("res://scenes/world/retro_material_style.gd")
const POWERED_MATERIALS := [&"tube", &"CoolerFluorescent"]
const ARCHITECTURE_MATERIALS := [&"tile", &"ceiling", &"plaster", &"brick"]
var _cache: Dictionary = {}
var _styled_materials: Dictionary = {}
var _vertex_materials: Array[BaseMaterial3D] = []
var _vertex_lighting := false

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_initial_style")

func _initial_style() -> void:
	if not is_inside_tree():
		return
	for node in get_parent().find_children("*", "MeshInstance3D", true, false):
		_style(node)
	for node in get_parent().find_children("*", "MultiMeshInstance3D", true, false):
		_style(node)
	# The player's retro setting may have enabled palette quantization during setup.
	# Keep the analog toggle, but the new art direction uses full material colors.
	for node in get_parent().get_children():
		if node.get_script() != null and node.get_script().resource_path.ends_with("retro_effects.gd"):
			node.palette_enabled = false
			node._sync_toggles()

func _on_node_added(node: Node) -> void:
	if (node is MeshInstance3D or node is MultiMeshInstance3D) and get_parent().is_ancestor_of(node):
		_style.call_deferred(node)

func set_vertex_lighting(enabled: bool) -> void:
	if _vertex_lighting == enabled:
		return
	_vertex_lighting = enabled
	for material in _vertex_materials:
		_set_shading(material)

func _set_shading(material: BaseMaterial3D) -> void:
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX if _vertex_lighting else BaseMaterial3D.SHADING_MODE_PER_PIXEL

func _style(node: GeometryInstance3D) -> void:
	if not is_inside_tree() or not is_instance_valid(node) or not get_parent().is_ancestor_of(node) or node.name == "PhoneScreen":
		return
	var authored := node.is_in_group("authored_materials")
	if node.material_override is BaseMaterial3D:
		node.material_override = _styled(node.material_override, authored)
		return
	if node.material_override != null:
		return
	if node is MeshInstance3D and node.mesh != null:
		for surface in node.mesh.get_surface_count():
			var material: Material = node.get_active_material(surface)
			if material is BaseMaterial3D:
				node.set_surface_override_material(surface, _styled(material, authored))
	elif node is MultiMeshInstance3D and node.multimesh != null:
		var mesh: Mesh = node.multimesh.mesh
		if mesh != null and mesh.get_surface_count() == 1 and mesh.surface_get_material(0) is BaseMaterial3D:
			node.material_override = _styled(mesh.surface_get_material(0), true)

func _styled(source: BaseMaterial3D, authored: bool) -> BaseMaterial3D:
	if _styled_materials.has(source) or source.resource_name in POWERED_MATERIALS:
		return source
	# The large shell faces need per-pixel lighting to keep local light pools and the phone torch defined.
	var vertex_eligible := source.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL \
		and source.resource_name not in ARCHITECTURE_MATERIALS
	if authored and not vertex_eligible:
		return source
	var key := [source.get_instance_id(), authored]
	if not _cache.has(key):
		var material := source.duplicate() as BaseMaterial3D
		if not authored:
			material.texture_filter = RetroMaterials.WORLD_FILTER
		if vertex_eligible:
			_vertex_materials.append(material)
			_set_shading(material)
		_styled_materials[material] = true
		_cache[key] = material
	return _cache[key]
