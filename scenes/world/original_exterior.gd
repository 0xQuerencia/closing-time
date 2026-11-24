class_name OriginalExterior
extends Node3D

const PSX = preload("res://assets/models/psx_pack/asset_loader.gd")

var materials: Dictionary = {}

func _ready() -> void:
	name = "OriginalExterior"
	_build_lot()
	_build_car(Vector3(-4.9,-.12,13.0))

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
	var asphalt := _mat(Color("#747675"),.82,"res://assets/models/exterior_asphalt.png")
	asphalt.uv1_scale = Vector3(9,9,9)
	var concrete := _mat(Color("#85837a"),.94,"res://assets/models/exterior_plaster.png")
	concrete.uv1_scale = Vector3(4,4,4)
	var ground := _mat(Color("#343c32"))
	var steel := _mat(Color("#575b54"),.72)
	var wood := _mat(Color("#776e58"),.92,"res://assets/models/exterior_wood.png")
	var paint := _mat(Color("#a99f78"))
	_box(self,Vector3(0,-.32,0),Vector3(90,.15,90),ground)
	_box(self,Vector3(0,-.23,15),Vector3(28,.22,18),asphalt,"Parking_asphalt")
	_box(self,Vector3(0,-.08,7),Vector3(20,.16,1.8),concrete)
	_box(self,Vector3(10.1,-.1,0),Vector3(2,.16,14),concrete)
	_box(self,Vector3(4,-.07,-7),Vector3(4,.18,2),concrete)
	# The existing collision ramp rises 12 cm toward the sidewalk.
	var ramp := _box(self,Vector3(1.7,-.09,8.525),Vector3(1.6,.05,1.25),concrete)
	ramp.rotation.x = -.0957
	for x in [-5.5,-2.5,.5]:
		PSX.place(self,"parking_stop",Vector3(x,-.12,9.65))
	for x in [-7.0,-4.0,-1.0,2.0]:
		_box(self,Vector3(x,-.115,12.3),Vector3(.075,.009,4.85),paint)
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
		PSX.place(self,"lamp_post",point,PI)
	for x in range(-10,11,2):
		PSX.place(self,"curb",Vector3(float(x),-.12,8.12),0,Vector3(.8,1,.25))
	PSX.place(self,"dumpster",Vector3(10.5,0,-3.7))
	# Keep collision bounds and the original chain-link fence. Dress the far edge.
	for i in range(9):
		PSX.place(self,"fence_segment",Vector3(-10.0+i*2.30,-.12,25.2))
	for x in [-12.0,12.0]:
		PSX.place(self,"road_barrier",Vector3(x,-.12,21.5))

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

func _build_car(at: Vector3) -> void:
	PSX.place(self,"wagon",at)

func _quad(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,d: Vector3) -> void:
	var n := (b-a).cross(c-a).normalized()
	for v in [a,b,c,a,c,d]:
		st.set_normal(n)
		st.add_vertex(v)
