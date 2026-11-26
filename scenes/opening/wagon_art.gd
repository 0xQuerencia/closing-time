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
	light.light_color = Color("#c0a278")
	light.light_energy = .54
	light.light_cull_mask = CABIN_MASK
	light.omni_range = 1.30
	wagon.add_child(light)

static func add_wiper(parent: Node3D) -> Node3D:
	var wiper := Node3D.new()
	wiper.name = "Wiper"
	wiper.position = Vector3(.30,.93,-.9)
	parent.add_child(wiper)
	var art := MeshArt.new()
	art.box(Vector3(-.15,.075,0),Vector3(.35,.018,.018),
		MeshArt.tile(3),Transform3D(Basis(Vector3.FORWARD,.45),Vector3(-.04,-.06,0)))
	art.box(Vector3(-.31,.164,0),Vector3(.39,.023,.025),MeshArt.tile(3))
	var finish := MeshArt.material(preload("res://assets/models/opening/route9_wagon_atlas.png"))
	art.attach(wiper,"Wiper arm and blade",finish)
	return wiper
