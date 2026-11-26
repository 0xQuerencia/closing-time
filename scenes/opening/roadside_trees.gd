extends RefCounted
## Flat-shaded 3D silhouettes with their origin at soil level. Shared between the drive and market.

const MeshArt = preload("res://scenes/opening/opening_mesh.gd")
const NEEDLES := [Color("#334138"),Color("#3e4b3d"),Color("#485143")]
const BARK := Color("#5a5145")
const DARK := Color("#2b352e")
var variations: Array[ArrayMesh] = []

func _init() -> void:
	var finish := MeshArt.material(null)
	finish.vertex_color_use_as_albedo = true
	finish.vertex_color_is_srgb = true
	for kind in range(3):
		var art := MeshArt.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 582 + kind * 119
		var trunk_top := Vector3(-.035,.81,.012) if kind == 2 else Vector3(.025,.95,0)
		_tier(art,rng,Vector3.ZERO,trunk_top,.027,.011,BARK,4)
		match kind:
			0:
				_tier(art,rng,Vector3(.018,.24,0),Vector3(-.018,.59,.015),.195,.021,NEEDLES[0],6)
				_tier(art,rng,Vector3(-.017,.42,0),Vector3(.029,.77,0),.156,.016,NEEDLES[1],6)
				_tier(art,rng,Vector3(.017,.61,0),Vector3(.034,1,0),.102,.002,NEEDLES[0],5)
			1:
				_tier(art,rng,Vector3(-.019,.36,-.02),Vector3(.04,.74,0),.136,.049,NEEDLES[0],5)
				_tier(art,rng,Vector3(.02,.56,.026),Vector3(.035,.9,0),.126,.037,NEEDLES[1],5)
				_tier(art,rng,Vector3(.036,.72,0),Vector3(.065,1,0),.08,.004,NEEDLES[1],4)
			2:
				_tier(art,rng,Vector3(-.013,.49,0),Vector3(-.126,.79,-.03),.015,.007,BARK,4)
				_tier(art,rng,Vector3(.007,.53,.014),Vector3(.124,.78,.05),.016,.008,BARK,4)
				_crown(art,rng,Vector3(-.099,.755,-.024),.140,.43,NEEDLES[1])
				_crown(art,rng,Vector3(.116,.740,.045),.130,.42,NEEDLES[0])
				_crown(art,rng,Vector3(0,.824,-.035),.162,.354,NEEDLES[2])
		variations.append(art.mesh(finish))

func batch(parent: Node3D, poses: Array, kind: int, label: String) -> void:
	if poses.is_empty():
		return
	var group := MultiMesh.new()
	group.transform_format = MultiMesh.TRANSFORM_3D
	group.use_colors = true
	group.mesh = variations[kind]
	group.instance_count = poses.size()
	for i in poses.size():
		group.set_instance_transform(i,poses[i][0])
		group.set_instance_color(i,poses[i][1])
	var instances := MultiMeshInstance3D.new()
	instances.name = label
	instances.multimesh = group
	instances.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instances)

func pose(rng: RandomNumberGenerator, at: Vector3, height: float) -> Array:
	var width := rng.randf_range(.72,1.25) * height
	var basis := Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3(width,height,width))
	var light := rng.randf_range(.64,1.0)
	return [Transform3D(basis,at),Color(light,light,light*.97)]

func _tier(art: RefCounted, rng: RandomNumberGenerator, low: Vector3, high: Vector3, radius: float,
		tip: float, color: Color, sides: int) -> void:
	var ring: Array[Vector3] = []
	for i in sides:
		var spin := TAU*i/sides
		var reach := radius*rng.randf_range(.76,1.16)
		ring.append(low+Vector3(cos(spin)*reach,rng.randf_range(-.075,.035) * minf(radius*7.0,1.0),sin(spin)*reach))
	for i in sides:
		var next := (i+1)%sides
		var a := ring[i]
		var b := ring[next]
		var c := high+(b-low).normalized()*tip
		var d := high+(a-low).normalized()*tip
		art.quad(b,a,d,c,Rect2(),color.darkened(.07*float(i%3)))
		art.triangle(low-Vector3.UP*.012,a,b,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,DARK)

func _crown(art: RefCounted, rng: RandomNumberGenerator, at: Vector3, radius: float, height: float, color: Color) -> void:
	_tier(art,rng,at-Vector3.UP*height*.13,at+Vector3.UP*height*.46,radius,.007,color,5)
	var pole := at-Vector3.UP*height*.48
	for i in range(5):
		var a := TAU*i/5
		var b := TAU*(i+1)/5
		art.triangle(pole,at+Vector3(cos(a),0,sin(a))*radius,at+Vector3(cos(b),0,sin(b))*radius,
			Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,color.darkened(.19))
