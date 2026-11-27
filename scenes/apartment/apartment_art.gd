extends RefCounted

const MeshArt = preload("res://scenes/opening/opening_mesh.gd")
const ATLAS = preload("res://assets/materials/opening/apartment_night_atlas.png")
const PLASTER = preload("res://assets/materials/opening/apartment_night_plaster.png")
const FLOOR = preload("res://assets/materials/opening/apartment_night_carpet.png")
const RUG = preload("res://assets/materials/opening/apartment_night_rug.png")
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
	floor_art.attach(room, "Woven apartment carpet", MeshArt.material(FLOOR, .96))
	var rug := MeshArt.new()
	rug.quad(Vector3(-1.63,.009,.71),Vector3(1.57,.009,.71),Vector3(1.57,.009,-1.40),Vector3(-1.63,.009,-1.40))
	rug.attach(room,"Patterned bedside rug",MeshArt.material(RUG,.95))

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
	_reference_dressing()
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
	var lamp_head := Vector3(1.30,1.427,-4.13)
	var tilt := Transform3D(Basis(Vector3.FORWARD,-.31),lamp_head)
	shade.box(Vector3.ZERO,Vector3(.177,.020,.150),MeshArt.tile(SHADE),tilt)
	var luminous := MeshArt.material(ATLAS)
	luminous.emission_enabled = true
	luminous.emission = Color("#dca664")
	luminous.emission_energy_multiplier = .5
	shade.attach(room,"Desk lamp inner diffuser",luminous)
	_light(room,"Lamp pool over shift note",Vector3(1.25,1.382,-4.04),Color("#ffd0a0"),2.12,3.45)
	_light(room,"Apartment exit jamb",Vector3(1.08,2.06,3.38),Color("#e7ccae"),.47,4.2)
	_light(room,"Night window fill",Vector3(.06,1.87,-3.95),Color("#abcadd") if morning else Color("#82a8da"),
		.75 if morning else .53,3.8)

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
	for x in [-3.0,-1.70]:
		_box(Vector3(x,.56,-3.46),Vector3(.10,1.10,.12),WALNUT)
		_box(Vector3(x,.21,-1.44),Vector3(.12,.40,.11),WALNUT)
		_box(Vector3(x,.31,-2.45),Vector3(.10,.17,2.02),OAK)
	_box(Vector3(-2.35,.33,-1.47),Vector3(1.37,.17,.105),WALNUT)
	_box(Vector3(-2.35,.77,-3.48),Vector3(1.28,.49,.084),WALNUT)
	_box(Vector3(-2.35,1.036,-3.46),Vector3(1.42,.055,.14),OAK)
	_taper(details,Vector3(-2.35,.449,-2.45),Vector2(1.37,1.94),Vector2(1.405,1.99),.194,LINEN)
	# Folds are silhouette geometry; the uninterrupted plaid uses the same atlas cell.
	var xs := [-3.07,-2.70,-2.35,-1.98,-1.63]
	var folds := [.566,.574,.586,.573,.566]
	var uv := MeshArt.tile(QUILT)
	for i in 4:
		var a := Vector3(xs[i],folds[i],-1.44)
		var b := Vector3(xs[i+1],folds[i+1],-1.44)
		var c := Vector3(xs[i+1],folds[i+1]-.008,-2.94)
		var d := Vector3(xs[i],folds[i]-.008,-2.94)
		var segment := Rect2(uv.position + Vector2(uv.size.x * i / 4.0,0),Vector2(uv.size.x*.25,uv.size.y))
		details.quad(a,b,c,d,segment)
		details.quad(a-Vector3(0,.246+(i%2)*.021,0),b-Vector3(0,.246+((i+1)%2)*.021,0),b,a,segment)
	for x in [-3.07,-1.63]:
		var mul := signf(x+2.35)
		var a := Vector3(x,.566,-2.94 if mul < 0.0 else -1.44)
		var b := Vector3(x,.566,-1.44 if mul < 0.0 else -2.94)
		details.quad(a-Vector3(0,.232,0),b-Vector3(0,.255,0),b,a,uv)
	_taper(details,Vector3(-2.35,.603,-3.13),Vector2(.89,.55),Vector2(.72,.40),.14,LINEN)
	_box(Vector3(-2.35,.61,-2.874),Vector3(.72,.015,.022),PUTTY)

func _beam(a: Vector3, b: Vector3, width: float, tile: int) -> void:
	var direction := (b-a).normalized()
	var across := Vector3.FORWARD.cross(direction).normalized()
	if across.length_squared() < .001:
		across = Vector3.RIGHT
	var pose := Transform3D(Basis(across,direction,across.cross(direction)),(a+b)*.5)
	details.box(Vector3.ZERO,Vector3(width,a.distance_to(b),width),MeshArt.tile(tile),pose)

func _desks() -> void:
	_box(Vector3(.65,.713,-3.91),Vector3(1.67,.074,.75),OAK)
	_box(Vector3(.65,.694,-3.514),Vector3(1.73,.044,.032),WALNUT)
	_box(Vector3(.64,.629,-4.235),Vector3(1.59,.143,.041),WALNUT)
	for z in [-4.19,-3.62]:
		_beam(Vector3(-.10,.03,z-.023),Vector3(-.08,.69,z),.063,WALNUT)
	_box(Vector3(1.25,.37,-3.91),Vector3(.44,.63,.66),WALNUT)
	for y in [.26,.50]:
		_box(Vector3(1.25,y,-3.576),Vector3(.399,.204,.034),OAK)
		_box(Vector3(1.25,y,-3.552),Vector3(.121,.024,.032),BRASS)
	_box(Vector3(1.33,.769,-4.12),Vector3(.27,.037,.22),STEEL)
	_beam(Vector3(1.367,.785,-4.13),Vector3(1.455,1.24,-4.14),.023,STEEL)
	_beam(Vector3(1.455,1.24,-4.14),Vector3(1.32,1.47,-4.13),.023,STEEL)
	_taper(details,Vector3(1.30,1.484,-4.13),Vector2(.226,.195),Vector2(.081,.084),.128,STEEL)
	_box(Vector3(-2.74,.727,3.70),Vector3(1.10,.083,.55),OAK)
	for x in [-3.18,-2.30]:
		for z in [3.49,3.91]:
			_box(Vector3(x,.35,z),Vector3(.075,.70,.075),WALNUT)
	_box(Vector3(-2.74,.62,3.72),Vector3(.88,.146,.42),WALNUT)
	_box(Vector3(-2.74,.62,3.497),Vector3(.13,.025,.04),BRASS)

func _reference_dressing() -> void:
	var chair := Vector3(-.33,0,-3.02)
	for x in [-.207,.207]:
		for z in [-.179,.179]:
			_beam(chair+Vector3(x*1.17,.024,z*1.18),chair+Vector3(x,.483,z),.049,WALNUT)
		_beam(chair+Vector3(x,.43,.166),chair+Vector3(x,.965,.237),.047,OAK)
	_box(chair+Vector3(0,.463,0),Vector3(.49,.071,.47),OAK)
	_box(chair+Vector3(0,.872,.224),Vector3(.45,.126,.038),WALNUT)
	# A decorative overshirt echoes the reference; the pickup remains on its existing collision target.
	var cloth_uv := MeshArt.tile(VEST)
	var cloth_top := PackedVector3Array([Vector3(-.225,.86,.242),Vector3(-.102,.956,.26),
		Vector3(.083,.942,.277),Vector3(.221,.866,.247)])
	var cloth_hem := PackedVector3Array([Vector3(-.253,.596,.27),Vector3(-.106,.54,.322),
		Vector3(.106,.565,.298),Vector3(.213,.643,.275)])
	for fold in 3:
		var band := Rect2(cloth_uv.position+Vector2(cloth_uv.size.x*fold/3.0,0),
			Vector2(cloth_uv.size.x/3.0,cloth_uv.size.y))
		details.quad(chair+cloth_hem[fold],chair+cloth_hem[fold+1],
			chair+cloth_top[fold+1],chair+cloth_top[fold],band)
	_box(Vector3(1.78,1.68,-4.392),Vector3(.71,.53,.043),WALNUT)
	_front(details,Vector3(1.78,1.68,-4.368),Vector2(.666,.485),SHADE)
	_front(details,Vector3(1.67,1.73,-4.361),Vector2(.234,.143),PHOTO)
	_front(details,Vector3(1.97,1.74,-4.357),Vector2(.118,.26),PAPER)
	_front(details,Vector3(1.81,1.57,-4.361),Vector2(.121,.106),PAPER)
	_box(Vector3(1.67,1.807,-4.352),Vector3(.022,.02,.025),BRASS)
	_box(Vector3(1.97,1.874,-4.352),Vector3(.020,.02,.025),BRASS)
	_box(Vector3(-1.79,1.74,-4.388),Vector3(.51,.43,.057),WALNUT)
	_front(details,Vector3(-1.79,1.74,-4.356),Vector2(.446,.363),PHOTO)
	_taper(details,Vector3(.94,.802,-4.12),Vector2(.081,.077),Vector2(.097,.093),.113,BRASS)
	for i in range(3):
		_beam(Vector3(.914 + i*.019,.82,-4.12),Vector3(.902+i*.03,.964,-4.111+.022*(i%2)),.011,STEEL)

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
		for fold in range(8):
			var x: float = side*(1.33-float(fold)*.050)
			var length: float = 1.26 + .023*(fold%3)
			var depth: float = .145 if fold%2 == 0 else .062
			_box(Vector3(x,2.35-length*.5,-4.30+depth*.2),Vector3(.061,length,depth),CURTAIN)

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

func _light(room: Node3D, label: String, at: Vector3, color: Color, energy: float, distance: float) -> void:
	var light := OmniLight3D.new()
	light.name = label
	light.position = at
	light.light_color = color
	light.light_energy = energy
	light.omni_range = distance
	room.add_child(light)
