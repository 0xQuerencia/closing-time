extends RefCounted
## Flat-shaded 3D silhouettes with their origin at soil level. Shared between the drive and market.

const MeshArt = preload("res://scenes/opening/opening_mesh.gd")
const NEEDLES := [Color("#334138"),Color("#3e4b3d"),Color("#485143")]
const BARK := Color("#5a5145")
const DARK := Color("#2b352e")
const BEND_LEAVES := [Color("#3f493a"),Color("#343e35"),Color("#444936")]
const BEND_BARK := Color("#514b40")
var variations: Array[ArrayMesh] = []

func _init(bend := false) -> void:
	var finish := MeshArt.material(null)
	finish.vertex_color_use_as_albedo = true
	finish.vertex_color_is_srgb = true
	for kind in range(3):
		var art := MeshArt.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 582 + kind * 119
		if bend and kind == 2:
			# Use pines for the two dense stand types, with bare deciduous trees as relief.
			_bend_tree(art,rng,kind)
			variations.append(art.mesh(finish))
			continue
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

func _bend_tree(art: RefCounted, rng: RandomNumberGenerator, kind: int) -> void:
	var elbow := Vector3(.031,.48,-.031)
	var fork := Vector3(.005,.72,.020) if kind == 0 else Vector3(-.073,.75,.025)
	var tip := Vector3(-.063,.99,.067) if kind == 2 else fork + Vector3(-.06,.17,0)
	_limb(art,Vector3(0,-.030,0),elbow,.035,.020)
	_limb(art,elbow,fork,.023,.012)
	_limb(art,fork,tip,.013,.003)
	var low_fork := Vector3(.101,.608,-.072)
	var high_fork := Vector3(-.162,.793,-.048)
	var low_tip := Vector3(.238,.799,-.103)
	var high_tip := Vector3(-.257,.919,-.009)
	if kind == 2:
		_limb(art,elbow,low_fork,.017,.010)
		_limb(art,low_fork,low_tip,.011,.003)
		_limb(art,fork,high_fork,.013,.008)
		_limb(art,high_fork,high_tip,.009,.0025)
		_limb(art,low_fork,Vector3(.108,.788,-.146),.008,.002)
		_limb(art,low_tip,Vector3(.254,.873,-.103),.004,.0015)
		_limb(art,high_fork,Vector3(-.160,.961,-.064),.006,.0015)
		_limb(art,fork,Vector3(.124,.879,.103),.011,.005)
		_limb(art,Vector3(.124,.879,.103),Vector3(.107,.982,.141),.005,.0015)
		return
	_limb(art,elbow,low_tip,.017,.004)
	_limb(art,fork,high_tip,.013,.003)
	if kind == 0:
		_lobe(art,rng,Vector3(-.097,.804,.023),Vector3(.212,.202,.175),BEND_LEAVES[0])
		_lobe(art,rng,Vector3(.167,.718,-.096),Vector3(.201,.188,.164),BEND_LEAVES[1])
		_lobe(art,rng,Vector3(-.226,.746,-.091),Vector3(.128,.153,.143),BEND_LEAVES[2])
	else:
		_lobe(art,rng,Vector3(-.145,.782,-.032),Vector3(.209,.204,.162),BEND_LEAVES[1])
		_lobe(art,rng,Vector3(.151,.674,.024),Vector3(.195,.135,.190),BEND_LEAVES[0])
		_lobe(art,rng,Vector3(-.060,.617,-.104),Vector3(.185,.138,.146),BEND_LEAVES[2])

func _limb(art: RefCounted, from: Vector3, to: Vector3, root: float, tip: float) -> void:
	var axis := (to-from).normalized()
	var right := axis.cross(Vector3.FORWARD).normalized()
	var front := right.cross(axis)
	var ring := [right,front,-right,-front]
	for i in ring.size():
		var a: Vector3 = ring[i]
		var b: Vector3 = ring[(i+1)%ring.size()]
		art.quad(from+b*root,from+a*root,to+a*tip,to+b*tip,Rect2(),BEND_BARK.darkened(.07*i))

func _lobe(art: RefCounted, rng: RandomNumberGenerator, at: Vector3, size: Vector3, shade: Color) -> void:
	var rim: Array[Vector3] = []
	var shoulders: Array[Vector3] = []
	var phase := rng.randf_range(0.0,TAU)
	for i in 5:
		var angle := phase+TAU*(float(i)+rng.randf_range(-.16,.16))/5.0
		var reach := rng.randf_range(.80,1.20)
		rim.append(at+size*Vector3(cos(angle)*reach,rng.randf_range(-.47,-.15),sin(angle)*reach))
		shoulders.append(at+size*Vector3(cos(angle+.16)*reach*.73,rng.randf_range(.31,.72),sin(angle+.16)*reach*.73))
	var top := at+size*Vector3(-.16,1.0,.14)
	var under := at+size*Vector3(.12,-.71,-.12)
	for i in 5:
		var j := (i+1)%5
		art.quad(rim[j],rim[i],shoulders[i],shoulders[j],Rect2(),shade.darkened(.06*(i%3)))
		art.triangle(shoulders[j],shoulders[i],top,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,shade.lightened(.033*(i%2)))
		art.triangle(under,rim[i],rim[j],Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,shade.darkened(.19))
