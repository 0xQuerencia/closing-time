extends RefCounted

const MeshArt = preload("res://scenes/opening/opening_mesh.gd")
const ATLAS = preload("res://assets/materials/opening/apartment_atlas.png")
const PLASTER = preload("res://assets/materials/opening/apartment_plaster.png")
const FLOOR = preload("res://assets/materials/opening/apartment_floor.png")
const WALNUT := 0
const OAK := 1
const QUILT := 2
const LINEN := 3
const STEEL := 4
const CURTAIN := 5
const NIGHT := 6
const NEWSPAPER := 7
const VEST := 8
const BRASS := 9
const PHONE := 10
const PAPER := 11
const DOOR := 12
const PHOTO := 13
const SHADE := 14
const PUTTY := 15

var details := MeshArt.new()
var finish := MeshArt.material(ATLAS)

func build(room: Node3D, morning: bool) -> void:
	var floor_art := MeshArt.new()
	floor_art.quad(Vector3(-3.5,0,4.5),Vector3(3.5,0,4.5),Vector3(3.5,0,-4.5),Vector3(-3.5,0,-4.5), Rect2(0,0,3,6))
	floor_art.attach(room, "Worn floorboards", MeshArt.material(FLOOR, .77))

	var walls := MeshArt.new()
	_wall(walls, Vector3(-3.425,0,4.425), Vector3(-3.425,0,-4.425))
	_wall(walls, Vector3(3.425,0,-4.425), Vector3(3.425,0,4.425))
	_wall(walls, Vector3(-3.425,0,-4.425), Vector3(3.425,0,-4.425))
	_wall(walls, Vector3(-.10,0,4.425), Vector3(-3.425,0,4.425))
	_wall(walls, Vector3(3.425,0,4.425), Vector3(1.60,0,4.425))
	_wall(walls, Vector3(1.60,2.345,4.425), Vector3(-.10,2.345,4.425), .345)
	walls.quad(Vector3(-3.425,2.69,-4.425),Vector3(3.425,2.69,-4.425),Vector3(3.425,2.69,4.425),Vector3(-3.425,2.69,4.425),Rect2(0,0,3,3))
	walls.attach(room, "Painted plaster", MeshArt.material(PLASTER))

	for x in [-3.405, 3.405]:
		_box(Vector3(x,.056,0),Vector3(.045,.112,8.85),PUTTY)
	for row in [[0.0,-4.403,6.8],[-1.78,4.40,3.30],[2.51,4.40,1.83]]:
		_box(Vector3(row[0],.056,row[1]),Vector3(row[2],.112,.046),PUTTY)
	_bed()
	_desks()
	_kitchen()
	_window(room, morning)
	_box(Vector3(.65,2.335,4.355),Vector3(1.55,.105,.125),PUTTY)
	_box(Vector3(1.46,1.17,4.445),Vector3(.305,2.34,.12),PUTTY)
	for x in [-.07,1.37]:
		_box(Vector3(x,1.165,4.355),Vector3(.105,2.33,.125),PUTTY)
		_box(Vector3(x,1.165,4.278),Vector3(.025,2.30,.03),OAK)
	_box(Vector3(-3.383,1.58,2.81),Vector3(.065,.10,.40),OAK)
	_box(Vector3(-3.33,1.58,2.82),Vector3(.10,.035,.040),BRASS)
	details.attach(room, "Furniture and fittings", finish)

	var shade := MeshArt.new()
	_taper(shade,Vector3(-.02,1.198,-4.11),Vector2(.32,.29),Vector2(.20,.185),.20,SHADE)
	var luminous := MeshArt.material(ATLAS)
	luminous.emission_enabled = true
	luminous.emission = Color("#dca664")
	luminous.emission_energy_multiplier = .5
	shade.attach(room,"Linen lamp shade",luminous)
	_light(room,Vector3(-.045,1.102,-4.01),Color("#ffc288"),1.6,3.8)
	_light(room,Vector3(.93,2.29,2.55),Color("#e4d6be"),.7,5.8)
	_light(room,Vector3(.16,1.89,-4.04),Color("#93b6ce") if morning else Color("#82b8df"),.7 if morning else .57,3.5)

func target(parent: Node3D, id: String) -> void:
	var art := MeshArt.new()
	match id:
		"apartment_exit":
			art.box(Vector3.ZERO,Vector3(1.28,2.28,.12),MeshArt.tile(DOOR))
			for y in [-.53,.44]:
				art.box(Vector3(0,y,-.062),Vector3(.93,.73,.024),MeshArt.tile(WALNUT))
				art.box(Vector3(0,y,-.08),Vector3(.84,.64,.024),MeshArt.tile(DOOR))
			art.box(Vector3(.49,-.10,-.085),Vector3(.085,.16,.028),MeshArt.tile(STEEL))
			art.box(Vector3(.48,-.08,-.131),Vector3(.13,.045,.09),MeshArt.tile(BRASS))
		"shift_read", "epilogue_phone":
			art.box(Vector3.ZERO,Vector3(.065,.039,.13),MeshArt.tile(STEEL))
			_top(art,Vector3(0,.020,0),Vector2(.062,.127),PHONE)
		"rent_notice", "epilogue_paper":
			var size := Vector2(.30,.33) if id == "epilogue_paper" else Vector2(.22,.29)
			art.box(Vector3.ZERO,Vector3(size.x,.012,size.y),MeshArt.tile(PUTTY))
			_top(art,Vector3(0,.007,0),size,PAPER if id == "rent_notice" else NEWSPAPER)
		"kay_photo":
			art.box(Vector3.ZERO,Vector3(.19,.23,.035),MeshArt.tile(WALNUT))
			_front(art,Vector3(0,0,.018),Vector2(.168,.203),PHOTO)
			art.box(Vector3(0,-.09,-.03),Vector3(.04,.08,.045),MeshArt.tile(STEEL))
		"keys_taken":
			for i in range(8):
				var angle := i * TAU / 8
				var center := Vector3(cos(angle)*.022,0,sin(angle)*.022-.008)
				var pose := Transform3D(Basis(Vector3.UP, -angle),center)
				art.box(Vector3.ZERO,Vector3(.006,.005,.018),MeshArt.tile(BRASS),pose)
			for i in [-1,1]:
				var pose := Transform3D(Basis(Vector3.UP, i*.43),Vector3(i*.019,-.003,.019))
				art.box(Vector3.ZERO,Vector3(.027,.007,.020),MeshArt.tile(BRASS),pose)
				art.box(Vector3(0,0,.018),Vector3(.010,.006,.032),MeshArt.tile(BRASS),pose)
				art.box(Vector3(.006,0,.025),Vector3(.011,.006,.007),MeshArt.tile(BRASS),pose)
			art.box(Vector3(-.036,.0,-.014),Vector3(.026,.013,.040),MeshArt.tile(VEST))
		"vest_taken":
			_vest(art)
	art.attach(parent, id, finish)

func _wall(art: RefCounted, a: Vector3, b: Vector3, height := 2.69) -> void:
	var up := Vector3.UP * height
	art.quad(a,b,b+up,a+up,Rect2(0,0,a.distance_to(b)/2.25,height/2.25))

func _box(at: Vector3, size: Vector3, tile: int) -> void:
	details.box(at,size,MeshArt.tile(tile))

func _taper(art: RefCounted, at: Vector3, low: Vector2, high: Vector2, height: float, cell: int) -> void:
	var a: Array[Vector3] = []
	var b: Array[Vector3] = []
	for corner in [Vector2(-1,1),Vector2(1,1),Vector2(1,-1),Vector2(-1,-1)]:
		a.append(at+Vector3(corner.x*low.x*.5,-height*.5,corner.y*low.y*.5))
		b.append(at+Vector3(corner.x*high.x*.5,height*.5,corner.y*high.y*.5))
	var uv := MeshArt.tile(cell)
	for i in range(4):
		var next := (i+1)%4
		art.quad(a[i],a[next],b[next],b[i],uv)
	art.quad(b[0],b[1],b[2],b[3],uv)
	art.quad(a[3],a[2],a[1],a[0],uv)

func _bed() -> void:
	for x in [-2.99,-1.71]:
		for z in [-3.43,-1.48]:
			_box(Vector3(x,.16,z),Vector3(.115,.32,.115),WALNUT)
		_box(Vector3(x,.30,-2.45),Vector3(.13,.19,2.1),WALNUT)
	_box(Vector3(-2.35,.31,-1.44),Vector3(1.46,.21,.12),WALNUT)
	_box(Vector3(-2.35,.53,-3.51),Vector3(1.47,.95,.10),WALNUT)
	_box(Vector3(-2.35,.89,-3.45),Vector3(1.28,.048,.04),OAK)
	_taper(details,Vector3(-2.35,.46,-2.45),Vector2(1.33,1.97),Vector2(1.40,2.02),.19,LINEN)
	_top(details,Vector3(-2.35,.586,-2.18),Vector2(1.42,1.45),QUILT)
	for x in [-1.635,-3.065]:
		var side := signf(x+2.35)
		var z1 := -1.46 if side > 0 else -2.90
		var z2 := -2.90 if side > 0 else -1.46
		details.quad(Vector3(x+side*.012,.38,z1),Vector3(x+side*.012,.38,z2),
			Vector3(x,.586,z2),Vector3(x,.586,z1),MeshArt.tile(QUILT))
	_front(details,Vector3(-2.35,.486,-1.45),Vector2(1.42,.20),QUILT)
	_taper(details,Vector3(-2.35,.604,-3.12),Vector2(.78,.42),Vector2(.66,.32),.12,LINEN)

func _desks() -> void:
	_box(Vector3(.65,.70,-3.91),Vector3(1.7,.10,.76),OAK)
	_box(Vector3(.65,.681,-3.515),Vector3(1.72,.045,.023),WALNUT)
	for x in [-.10,1.40]:
		for z in [-4.19,-3.64]:
			_box(Vector3(x,.34,z),Vector3(.075,.68,.074),WALNUT)
	_box(Vector3(1.21,.54,-3.87),Vector3(.42,.22,.63),WALNUT)
	_box(Vector3(1.21,.54,-3.541),Vector3(.37,.14,.025),OAK)
	_box(Vector3(1.21,.54,-3.514),Vector3(.11,.024,.034),STEEL)
	_box(Vector3(-.02,.775,-4.11),Vector3(.20,.05,.19),STEEL)
	_box(Vector3(-.02,.925,-4.11),Vector3(.032,.29,.032),BRASS)
	_box(Vector3(-.02,.755,-4.28),Vector3(.013,.013,.24),STEEL)
	_box(Vector3(-2.74,.72,3.70),Vector3(1.10,.10,.55),OAK)
	for x in [-3.18,-2.30]:
		for z in [3.49,3.91]:
			_box(Vector3(x,.35,z),Vector3(.07,.7,.075),WALNUT)
	_box(Vector3(-2.74,.58,3.72),Vector3(.88,.15,.42),WALNUT)
	_box(Vector3(-2.74,.58,3.497),Vector3(.13,.025,.04),BRASS)

func _kitchen() -> void:
	_box(Vector3(2.93,.43,-1.55),Vector3(.95,.86,2.6),OAK)
	_box(Vector3(2.93,.90,-1.55),Vector3(1.02,.08,2.68),PUTTY)
	for z in [-2.41,-1.55,-.69]:
		_box(Vector3(2.444,.43,z),Vector3(.029,.69,.80),WALNUT)
		_box(Vector3(2.424,.44,z),Vector3(.028,.59,.68),OAK)
		_box(Vector3(2.397,.69,z),Vector3(.028,.024,.16),STEEL)
	_box(Vector3(2.95,.952,-2.29),Vector3(.60,.029,.54),STEEL)
	_box(Vector3(2.95,.967,-2.29),Vector3(.49,.014,.44),NIGHT)
	_box(Vector3(3.20,1.032,-2.29),Vector3(.028,.16,.028),STEEL)
	_box(Vector3(3.14,1.10,-2.29),Vector3(.14,.027,.028),STEEL)
	_box(Vector3(3.02,.83,1.2),Vector3(.80,1.65,.76),PUTTY)
	_box(Vector3(2.609,1.41,1.2),Vector3(.027,.47,.739),PUTTY)
	_box(Vector3(2.608,.585,1.2),Vector3(.03,1.12,.74),PUTTY)
	_box(Vector3(2.586,1.12,1.2),Vector3(.015,.025,.72),STEEL)
	for y in [.91,1.30]:
		_box(Vector3(2.573,y,1.47),Vector3(.058,.23,.04),STEEL)

func _window(room: Node3D, morning: bool) -> void:
	var width := 2.08
	var art := MeshArt.new()
	_front(art,Vector3(.01,1.70,-4.411),Vector2(width,1.10),NIGHT)
	var glass := MeshArt.material(ATLAS)
	glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glass.albedo_color = Color(.78,.87,1.0)
	if morning:
		var sky := GradientTexture2D.new()
		sky.gradient = Gradient.new()
		sky.gradient.colors = PackedColorArray([Color("#95abb8"),Color("#ced1bc")])
		sky.fill_to = Vector2(0,1)
		glass.albedo_texture = sky
		glass.albedo_color = Color.WHITE
	art.attach(room,"Window view",glass)
	for x in [-1.06,0.01,1.08]:
		_box(Vector3(x,1.70,-4.38),Vector3(.047,1.14,.085),PUTTY)
	for y in [1.13,1.65,2.27]:
		_box(Vector3(.01,y,-4.371),Vector3(2.18,.046,.10),PUTTY)
	_box(Vector3(.01,1.12,-4.32),Vector3(2.22,.051,.184),OAK)
	_box(Vector3(.01,2.37,-4.30),Vector3(2.52,.023,.027),STEEL)
	for side in [-1.0,1.0]:
		for fold in range(6):
			var x: float = side*(1.15-float(fold)*.052)
			var length: float = .99 + .015*(fold%3)
			var depth: float = .12 if fold%2 == 0 else .06
			_box(Vector3(x,2.35-length*.5,-4.31+depth*.2),Vector3(.065,length,depth),CURTAIN)

func _vest(art: RefCounted) -> void:
	var uv := MeshArt.tile(VEST)
	for side in [-1.0,1.0]:
		var points := [
			Vector2(.006,-.258),Vector2(.211,-.256),Vector2(.215,-.017),
			Vector2(.161,.075),Vector2(.189,.204),Vector2(.084,.261),Vector2(.013,.116)
		]
		var center := Vector3(.074,-.051,.105*side)
		for i in range(points.size()):
			var a: Vector2 = points[i]
			var b: Vector2 = points[(i+1)%points.size()]
			var first := Vector3(.045+float(i%2)*.009,a.y,a.x*side)
			var second := Vector3(.045+float((i+1)%points.size()%2)*.009,b.y,b.x*side)
			var uv_a := uv.position+uv.size*Vector2(a.x/.23,.5-a.y)
			var uv_b := uv.position+uv.size*Vector2(b.x/.23,.5-b.y)
			if side < 0:
				art.triangle(center, first, second, uv.get_center(), uv_a, uv_b)
			else:
				art.triangle(center, second, first, uv.get_center(), uv_b, uv_a)
	art.box(Vector3(.068,-.083,0),Vector3(.018,.30,.013),MeshArt.tile(STEEL))
	art.box(Vector3(.061,.095,.11),Vector3(.017,.031,.057),MeshArt.tile(PUTTY))

func _front(art: RefCounted, at: Vector3, size: Vector2, tile: int) -> void:
	var right := Vector3.RIGHT*size.x*.5
	var up := Vector3.UP*size.y*.5
	art.quad(at-right-up,at+right-up,at+right+up,at-right+up,MeshArt.tile(tile))

func _top(art: RefCounted, at: Vector3, size: Vector2, tile: int) -> void:
	var right := Vector3.RIGHT*size.x*.5
	var back := Vector3.BACK*size.y*.5
	art.quad(at-right+back,at+right+back,at+right-back,at-right-back,MeshArt.tile(tile))

func _light(room: Node3D, at: Vector3, color: Color, energy: float, distance: float) -> void:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = color
	light.light_energy = energy
	light.omni_range = distance
	room.add_child(light)
