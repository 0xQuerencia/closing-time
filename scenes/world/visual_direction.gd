extends Node
## Shared material treatment for world props and late-spawned characters.
## Cache duplicates to preserve batching; do not touch UI, LCD or CCTV shaders.
var _cache: Dictionary = {}

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_initial_style")

func _initial_style() -> void:
	for node in get_parent().find_children("*", "MeshInstance3D", true, false):
		_style(node)

func _on_node_added(node: Node) -> void:
	if node is MeshInstance3D:
		_style.call_deferred(node)

func _style(node: MeshInstance3D) -> void:
	if not is_instance_valid(node) or node.mesh == null or node.name in ["PhoneScreen","OriginalCRTGlass","ScanWindow"]:
		return
	if node.material_override is BaseMaterial3D:
		node.material_override = _filtered(node.material_override)
		return
	for surface in node.mesh.get_surface_count():
		var material := node.get_active_material(surface)
		if material is BaseMaterial3D:
			node.set_surface_override_material(surface, _filtered(material))

func _filtered(source: BaseMaterial3D) -> BaseMaterial3D:
	var key := source.get_instance_id()
	if not _cache.has(key):
		var material := source.duplicate() as BaseMaterial3D
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		_cache[key] = material
	return _cache[key]
