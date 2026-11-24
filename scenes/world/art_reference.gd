extends RefCounted
## The previously used authored scene and credited legacy models are opt-in playtest assets.
const RetroMaterials = preload("res://scenes/world/retro_material_style.gd")
const PROPS := {
	"desk":"res://assets/models/office_props/desk_office.glb",
	"chair":"res://assets/models/office_props/chair_office.glb",
	"crt":"res://assets/models/office_props/crt_monitor__static.glb",
	"computer":"res://assets/models/props/desktop_pc.glb",
	"keyboard":"res://assets/models/office_props/keyboard.glb",
	"phone":"res://assets/models/office_props/desk_phone.glb",
	"mug":"res://assets/models/props/mug.glb",
	"crate":"res://assets/models/props/bottle_crate.glb",
	"extinguisher":"res://assets/models/props/fire_extinguisher.glb",
	"camera":"res://assets/models/props/cctv_a.glb"
}
static func active() -> bool:
	return OS.has_feature("art_reference") or (OS.has_feature("editor") and "--art-reference" in OS.get_cmdline_user_args())

static func scene(path: String) -> Node3D:
	if not active() or not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var model := packed.instantiate() as Node3D
	if model != null:
		RetroMaterials.apply_nearest_filter(model)
	return model

static func crt_surface(root: Node) -> Dictionary:
	if root == null:
		return {}
	var original := root.find_child("OriginalCRTGlass",true,false) as MeshInstance3D
	if original != null:
		return {"mesh":original,"surface":-1}
	for child in root.find_children("*","MeshInstance3D",true,false):
		var mesh := child as MeshInstance3D
		if mesh.mesh == null:
			continue
		for surface in mesh.mesh.get_surface_count():
			var mat := mesh.mesh.surface_get_material(surface)
			if mat != null and mat.resource_name == "prop_crt_screen_static":
				return {"mesh":mesh,"surface":surface}
	return {}

static func prop(id: String, factory: OriginalOfficeProps) -> Node3D:
	return factory.make(id)

static func set_screen(root: Node, material: Material) -> bool:
	var target := crt_surface(root)
	if target.is_empty():
		return false
	var mesh: MeshInstance3D = target.mesh
	if target.surface < 0:
		mesh.material_override = material
	else:
		mesh.set_surface_override_material(target.surface,material)
	return true

static func customer(id: String) -> Node3D:
	# Keep the owner's actual Jamie/Leon meshes. The previous male shopper meshes
	# are reference-only until equivalent distinct original models are authored.
	var path := ""
	match id:
		"ben": path = "res://assets/models/characters/young_man.glb"
		"gus": path = "res://assets/models/characters/office_worker.glb"
	if not path.is_empty():
		var model := scene(path)
		if model != null:
			return model
	return OriginalCast.instantiate(id)
