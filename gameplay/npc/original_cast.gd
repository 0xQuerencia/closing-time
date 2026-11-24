class_name OriginalCast
extends RefCounted

const JAMIE := "res://assets/models/characters/original/jamie_lod0.glb"
const LEON := "res://assets/models/characters/original/leon_lod0.glb"
const CAST := {
	"mara": {"height":.92,"width":1.10,"coat":Color("#c0b8a0"),"pants":Color("#747d72"),"skin":Color("#f2ded0"),"hair":Color("#86765e"),"style":"bob","glasses":true},
	"ben": {"height":1.025,"width":1.08,"coat":Color("#8d9b95"),"pants":Color("#7a858d"),"skin":Color("#bfa58f"),"hair":Color("#3a332d"),"style":"short","glasses":false},
	"nora": {"height":.91,"width":.92,"coat":Color("#aba9c8"),"pants":Color("#606b86"),"skin":Color("#d9b89d"),"hair":Color("#41352b"),"style":"long","glasses":false},
	"ruth": {"height":.89,"width":1.14,"coat":Color("#b5a29a"),"pants":Color("#82746c"),"skin":Color("#e8d5b7"),"hair":Color("#b4b0a4"),"style":"bun","glasses":true},
	"dina": {"height":.94,"width":1.00,"coat":Color("#b0a1a0"),"pants":Color("#777c78"),"skin":Color("#d3b39d"),"hair":Color("#46382e"),"style":"bun","glasses":false},
	"gus": {"height":1.04,"width":1.18,"coat":Color("#a8ac8b"),"pants":Color("#747d85"),"skin":Color("#bd9d82"),"hair":Color("#554637"),"style":"short","glasses":false},
	"leon2": {"height":1.0,"width":1.0,"coat":Color("#8a9698"),"pants":Color.WHITE,"skin":Color.WHITE,"hair":Color("#443b30"),"style":"cap","glasses":false}
}
static var _mesh_cache: Dictionary = {}

static func instantiate(id: String) -> Node3D:
	var leon := id.begins_with("leon")
	var packed := load(LEON if leon else JAMIE) as PackedScene
	if packed == null:
		return null
	var model := packed.instantiate() as Node3D
	if CAST.has(id):
		_customize(model,id,CAST[id])
	return model

static func _customize(model: Node3D, id: String, spec: Dictionary) -> void:
	model.scale = Vector3(spec.width,spec.height,spec.width)
	for child in model.find_children("*","MeshInstance3D",true,false):
		var instance := child as MeshInstance3D
		var source := instance.mesh as ArrayMesh
		if source == null:
			continue
		var key := "%s:%s" % [id,source.resource_name]
		if _mesh_cache.has(key):
			instance.mesh = _mesh_cache[key]
			continue
		var mesh := ArrayMesh.new()
		for surface in source.get_surface_count():
			var arrays := source.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var colors := PackedColorArray()
			colors.resize(vertices.size())
			for i in vertices.size():
				var v := vertices[i]
				var coat: Color = spec.coat
				var pants: Color = spec.pants
				var skin: Color = spec.skin
				var hair: Color = spec.hair
				if v.y > 1.71:
					colors[i] = hair.lerp(Color.WHITE,.30)
				elif v.y > 1.52 or (absf(v.x) > .22 and v.y < 1.02 and v.y > .72):
					colors[i] = skin
				elif v.y > .87:
					colors[i] = coat
				elif v.y > .14:
					colors[i] = pants
				else:
					colors[i] = Color("#9c9a95")
			arrays[Mesh.ARRAY_COLOR] = colors
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			var material := source.surface_get_material(surface) as StandardMaterial3D
			if material != null:
				var tint := material.duplicate() as StandardMaterial3D
				tint.vertex_color_use_as_albedo = true
				tint.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				mesh.surface_set_material(surface,tint)
		instance.mesh = mesh
		_mesh_cache[key] = mesh
	var rigs := model.find_children("*","Skeleton3D",true,false)
	if rigs.is_empty():
		return
	var rig := rigs[0] as Skeleton3D
	var head := BoneAttachment3D.new()
	head.bone_name = "Head"
	rig.add_child(head)
	var hair_color: Color = spec.hair
	match str(spec.style):
		"bob":
			_box(head,Vector3(.205,.18,.18),Vector3(0,.115,-.045),hair_color)
			for x in [-.09,.09]:
				_box(head,Vector3(.045,.15,.10),Vector3(x,.045,.005),hair_color)
		"long":
			_box(head,Vector3(.18,.26,.085),Vector3(0,.035,-.085),hair_color)
			for x in [-.085,.085]:
				_box(head,Vector3(.035,.20,.08),Vector3(x,.035,-.05),hair_color)
		"bun":
			var bun := SphereMesh.new()
			bun.radius = .073
			bun.height = .12
			bun.radial_segments = 7
			bun.rings = 3
			_part(head,bun,Vector3(0,.12,-.12),hair_color)
		"cap":
			var cap := CylinderMesh.new()
			cap.top_radius = .09
			cap.bottom_radius = .112
			cap.height = .07
			cap.radial_segments = 8
			cap.rings = 0
			_part(head,cap,Vector3(0,.19,0),Color("#39423e"))
			_box(head,Vector3(.18,.012,.12),Vector3(0,.16,.105),Color("#39423e"))
	if spec.glasses:
		for x in [-.042,.042]:
			_box(head,Vector3(.070,.012,.012),Vector3(x,.088,.116),Color("#333430"))
			_box(head,Vector3(.070,.010,.012),Vector3(x,.046,.116),Color("#333430"))
			for dx in [-.031,.031]:
				_box(head,Vector3(.010,.042,.012),Vector3(x+dx,.067,.116),Color("#333430"))
		_box(head,Vector3(.020,.009,.012),Vector3(0,.072,.116),Color("#333430"))

static func _box(parent: Node3D,size: Vector3,at: Vector3,color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_part(parent,mesh,at,color)

static func _part(parent: Node3D,mesh: Mesh,at: Vector3,color: Color) -> void:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = .9
	part.material_override = material
	parent.add_child(part)
