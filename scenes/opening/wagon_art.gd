extends RefCounted

const MODEL = preload("res://assets/models/opening/route9_wagon.glb")
const MeshArt = preload("res://scenes/opening/opening_mesh.gd")
const CABIN_MASK := 1 << 5

static func install(parent: Node3D, at: Vector3 = Vector3.ZERO) -> Node3D:
	var wagon := MODEL.instantiate() as Node3D
	wagon.name = "Route9Wagon"
	wagon.position = at
	for child in wagon.find_children("*","MeshInstance3D",true,false):
		child.add_to_group("authored_materials")
		if child.get_active_material(0).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(wagon)
	return wagon

static func add_cabin_light(wagon: Node3D) -> void:
	for label in ["DashboardAndUpholstery","SteeringWheel"]:
		var group := wagon.get_node(label) as MeshInstance3D
		group.layers |= CABIN_MASK
	var light := OmniLight3D.new()
	light.name = "Dashboard light"
	light.position = Vector3(-.08,1.13,-.19)
	light.light_color = Color("#c29a72")
	light.light_energy = .46
	light.light_cull_mask = CABIN_MASK
	light.omni_range = 1.30
	wagon.add_child(light)

# Fixed tinted inset, not a reflection viewport or a third live camera.
static func add_rearview_mirror(wagon: Node3D) -> void:
	var housing := MeshArt.new()
	var pivot := Vector3(.072,1.386,-.683)
	housing.box(pivot,Vector3(.414,.107,.037),Rect2(),Transform3D.IDENTITY,Color("#49382d"))
	housing.box(pivot+Vector3(0,.062,-.014),Vector3(.043,.067,.031),Rect2(),Transform3D.IDENTITY,Color("#423831"))
	housing.box(pivot+Vector3(0,0,.023),Vector3(.365,.071,.013),Rect2(),Transform3D.IDENTITY,Color("#38454b"))
	var finish := MeshArt.material(null,.61)
	finish.vertex_color_use_as_albedo = true
	finish.vertex_color_is_srgb = true
	housing.attach(wagon,"Fixed tinted rear-view mirror",finish)

static func add_wiper(parent: Node3D) -> Node3D:
	var mount := Node3D.new()
	mount.name = "Wiper mount"
	mount.position = Vector3(.26,.834,-1.070)
	mount.rotation.x = atan2(.517,.737)
	parent.add_child(mount)
	var wiper := Node3D.new()
	wiper.name = "Wiper"
	mount.add_child(wiper)
	var art := MeshArt.new()
	art.box(Vector3(-.218,0,0),Vector3(.436,.010,.009))
	art.box(Vector3(-.437,.012,.003),Vector3(.336,.009,.013))
	art.box(Vector3(-.422,.005,0),Vector3(.034,.020,.018))
	var finish := MeshArt.material(null,.77)
	finish.albedo_color = Color("#242725")
	art.attach(wiper,"Wiper arm and blade",finish)
	return wiper
