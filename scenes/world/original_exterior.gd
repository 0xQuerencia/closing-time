class_name OriginalExterior
extends Node3D

const WagonArt = preload("res://scenes/opening/wagon_art.gd")
const MeshArt = preload("res://scenes/opening/opening_mesh.gd")
const ASPHALT = preload("res://assets/materials/opening/route9_night_asphalt.png")

var materials: Dictionary = {}

func _ready() -> void:
	name = "OriginalExterior"
	_build_lot()
	WagonArt.install(self,Vector3(-4.9,-.12,13.0))

func _mat(color: Color,rough := .9,texture_path := "") -> StandardMaterial3D:
	var key := "%s:%s:%s" % [color.to_html(),rough,texture_path]
	if materials.has(key):
		return materials[key] as StandardMaterial3D
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if not texture_path.is_empty() and ResourceLoader.exists(texture_path):
		m.albedo_texture = load(texture_path)
	materials[key] = m
	return m

func _box(parent: Node3D,at: Vector3,size: Vector3,material: Material,label := "") -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	var node := MeshInstance3D.new()
	node.mesh = b
	node.material_override = material
	node.position = at
	if not label.is_empty():
		node.name = label
	parent.add_child(node)
	return node

func _build_lot() -> void:
	var asphalt := MeshArt.material(ASPHALT,.74)
	asphalt.albedo_color = Color("#d7dddd")
	asphalt.metallic_specular = .30
	# Textured bounce from the canopy keeps asphalt diffuse legible between the
	# individual pools, entirely on the real ground mesh.
	asphalt.emission_enabled = true
	asphalt.emission_texture = ASPHALT
	asphalt.emission = Color("#514031")
	asphalt.emission_energy_multiplier = .31
	var paving := MeshArt.new()
	# The one-metre grid gives low-tier vertex lighting enough samples for the lot's practical pools.
	for x in range(-14, 14):
		for z in range(6, 24):
			paving.quad(Vector3(x, -.12, z + 1), Vector3(x + 1, -.12, z + 1),
				Vector3(x + 1, -.12, z), Vector3(x, -.12, z),
				Rect2((x + 14) * .3125, (z - 6) * .3125, .3125, .3125))
	paving.attach(self,"Parking_asphalt",asphalt)
	var concrete := _mat(Color("#85837a"),.94,"res://assets/models/exterior_plaster.png")
	concrete.uv1_scale = Vector3(4,4,4)
	var ground := _mat(Color("#343c32"))
	var steel := _mat(Color("#575b54"),.72)
	var wood := _mat(Color("#776e58"),.92,"res://assets/models/exterior_wood.png")
	_box(self,Vector3(0,-.32,0),Vector3(90,.15,90),ground)
	_box(self,Vector3(0,-.08,7),Vector3(20,.16,1.8),concrete)
	_box(self,Vector3(10.1,-.1,0),Vector3(2,.16,14),concrete)
	_box(self,Vector3(4,-.07,-7),Vector3(4,.18,2),concrete)
	# The existing collision ramp rises 12 cm toward the sidewalk.
	var ramp := _box(self,Vector3(1.7,-.09,8.525),Vector3(1.6,.05,1.25),concrete)
	ramp.rotation.x = -.0957
	for x in [-5.5,-2.5,.5]:
		_box(self,Vector3(x,-.01,9.65),Vector3(1.6,.19,.16),concrete)
	_parking_marks()
	for x in [-8.5,8.5]:
		_box(self,Vector3(x,1.6,7),Vector3(.16,3.2,.16),steel)
	_box(self,Vector3(0,3.19,6.9),Vector3(18.5,.18,2.3),concrete)
	for z in [-9.0,23.0]:
		for x in range(-14,15,2):
			_box(self,Vector3(x,.9,z),Vector3(.09,1.8,.09),steel)
		# Low-resolution wire fence from repeated diagonal line segments.
		_fence(Vector3(-14,0,z),Vector3(14,0,z),steel)
	for x in [-14.0,14.0]:
		_fence(Vector3(x,0,-9),Vector3(x,0,23),steel)
	for point in [Vector3(-10,0,15),Vector3(11,0,23)]:
		_box(self,point+Vector3(0,.18,0),Vector3(.38,.5,.38),concrete)
		_box(self,point+Vector3(0,2.75,0),Vector3(.12,5.5,.12),steel)
		_box(self,point+Vector3(0,5.5,-.5),Vector3(.34,.12,1.15),steel)
	var dumpster := _mat(Color("#444b3e"))
	_box(self,Vector3(10.5,.65,-3.7),Vector3(1.4,1.3,2),dumpster)
	_box(self,Vector3(10.5,1.33,-3.7),Vector3(1.5,.13,2.08),steel)
	for z in [-4.45,-3.95,-3.45,-2.95]:
		_box(self,Vector3(9.78,.65,z),Vector3(.07,1.10,.09),steel)

func _fence(a: Vector3,b: Vector3,material: Material) -> void:
	var length := a.distance_to(b)
	var direction := (b-a).normalized()
	var middle := (a+b)*.5
	var yaw := atan2(direction.x,direction.z)
	for y in [.15,1.75]:
		var rail := _box(self,middle+Vector3(0,y,0),Vector3(.04,.04,length),material)
		rail.rotation.y = yaw
	# Batch the sparse wire mesh as a single surface.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	for i in range(int(length/.24)+1):
		var t := float(i)*.24
		for sign in [-1.0,1.0]:
			var finish := clampf(t+sign*.85,0,length)
			st.add_vertex(a+direction*t+Vector3(0,.16,0))
			st.add_vertex(a+direction*finish+Vector3(0,1.73,0))
	var mesh := st.commit()
	var wire := MeshInstance3D.new()
	wire.mesh = mesh
	wire.material_override = material
	add_child(wire)

func _parking_marks() -> void:
	var paint := MeshArt.new()
	var grain := MeshArt.material(null)
	grain.vertex_color_use_as_albedo = true
	grain.vertex_color_is_srgb = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 241106
	for x in [-7.0,-4.0,-1.0,2.0,5.0,8.0]:
		var z := 9.875
		while z < 14.725:
			var end := minf(z+rng.randf_range(.095,.57),14.725)
			var shift := rng.randf_range(-.016,.017)
			var left: float = x+shift-.047
			var right: float = x+shift+.047
			paint.quad(Vector3(left,-.113,end),Vector3(right,-.113,end),
				Vector3(right,-.113,z),Vector3(left,-.113,z),Rect2(),Color("#b5a681").darkened(rng.randf_range(0,.44)))
			z = end+rng.randf_range(.01,.11)
	paint.attach(self,"Chipped parking bay lines",grain)

	var sidewalk := MeshArt.new()
	for x in range(-8,10,2):
		if x == 2:
			continue
		sidewalk.box(Vector3(x,.001,7.04),Vector3(.014,.006,1.65))
	sidewalk.attach(self,"Sidewalk expansion joints",_mat(Color("#494941")))
