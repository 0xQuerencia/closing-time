class_name OriginalExterior
extends Node3D

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
		_box(self,Vector3(x,-.01,9.65),Vector3(1.6,.19,.16),concrete)
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

func _build_car(at: Vector3) -> void:
	var car := Node3D.new()
	car.name = "Original_2001_Wagon"
	car.position = at
	add_child(car)
	var paint := _mat(Color("#777b7b"),.48)
	var trim := _mat(Color("#34383a"),.8)
	var glass := _mat(Color("#29343a"),.3)
	var rubber := _mat(Color("#222424"),.95)
	var hub := _mat(Color("#969b98"),.5)
	var red := _mat(Color("#903832"),.55)
	var amber := _mat(Color("#b18446"),.55)
	var light := _mat(Color("#d0c9ab"),.35)
	# Original cross-section body; the taper at both ends avoids a cube silhouette.
	var rings := [
		Vector3(.72,.43,-2.06),Vector3(.86,.58,-1.76),Vector3(.87,.67,-.95),
		Vector3(.86,.68,.65),Vector3(.83,.62,1.75),Vector3(.73,.48,2.04)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(rings.size()-1):
		var a: Vector3 = rings[i]
		var b: Vector3 = rings[i+1]
		var va := [Vector3(-a.x,.22,a.z),Vector3(a.x,.22,a.z),Vector3(a.x,a.y,a.z),Vector3(-a.x,a.y,a.z)]
		var vb := [Vector3(-b.x,.22,b.z),Vector3(b.x,.22,b.z),Vector3(b.x,b.y,b.z),Vector3(-b.x,b.y,b.z)]
		for j in range(4):
			var k := (j+1)%4
			_quad(st,va[j],va[k],vb[k],vb[j])
	var mesh := st.commit()
	var body := MeshInstance3D.new()
	body.mesh = mesh
	body.material_override = paint
	car.add_child(body)
	_box(car,Vector3(0,.30,-2.04),Vector3(1.46,.27,.16),trim)
	_box(car,Vector3(0,.30,2.02),Vector3(1.46,.28,.16),trim)
	_box(car,Vector3(0,1.31,.20),Vector3(1.40,.075,2.12),paint)
	var cabin := SurfaceTool.new()
	cabin.begin(Mesh.PRIMITIVE_TRIANGLES)
	_quad(cabin,Vector3(-.81,.68,-.97),Vector3(.81,.68,-.97),Vector3(.68,1.27,-.86),Vector3(-.68,1.27,-.86))
	_quad(cabin,Vector3(.81,.68,1.74),Vector3(-.81,.68,1.74),Vector3(-.68,1.27,1.25),Vector3(.68,1.27,1.25))
	for side in [-1.0,1.0]:
		_quad(cabin,Vector3(side*.82,.68,-.97),Vector3(side*.82,.68,1.74),Vector3(side*.70,1.27,1.25),Vector3(side*.70,1.27,-.86))
	var windows := MeshInstance3D.new()
	windows.mesh = cabin.commit()
	windows.material_override = glass
	car.add_child(windows)
	for x in [-.82,.82]:
		for z in [-.8,.20,1.18]:
			_box(car,Vector3(x*.94,.98,z),Vector3(.055,.60,.055),paint)
		for z in [-.32,.82]:
			_box(car,Vector3(x*1.01,.65,z),Vector3(.035,.045,.16),trim)
		_box(car,Vector3(x,.91,-.68),Vector3(.19,.12,.19),trim)
		for z in [-1.37,1.36]:
			var wheel := CylinderMesh.new()
			wheel.top_radius = .30
			wheel.bottom_radius = .30
			wheel.height = .18
			wheel.radial_segments = 12
			wheel.rings = 0
			var wi := MeshInstance3D.new()
			wi.mesh = wheel
			wi.rotation.z = PI/2
			wi.position = Vector3(x,.29,z)
			wi.material_override = rubber
			car.add_child(wi)
			var rim := CylinderMesh.new()
			rim.top_radius = .18
			rim.bottom_radius = .18
			rim.height = .022
			rim.radial_segments = 10
			rim.rings = 0
			var ri := MeshInstance3D.new()
			ri.mesh = rim
			ri.rotation.z = PI/2
			ri.position = Vector3(x+signf(x)*.095,.29,z)
			ri.material_override = hub
			car.add_child(ri)
	for x in [-.54,.54]:
		_box(car,Vector3(x,.52,-2.07),Vector3(.31,.13,.025),light)
		_box(car,Vector3(x,.51,2.05),Vector3(.25,.17,.025),red)
		_box(car,Vector3(x,.41,2.065),Vector3(.23,.05,.02),amber)
	_box(car,Vector3(0,.47,-2.08),Vector3(.63,.10,.025),trim)
	_box(car,Vector3(0,.46,2.07),Vector3(.33,.10,.025),light)

func _quad(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,d: Vector3) -> void:
	var n := (b-a).cross(c-a).normalized()
	for v in [a,b,c,a,c,d]:
		st.set_normal(n)
		st.add_vertex(v)
