class_name ExteriorDressing
extends Node3D
## Night-lot dressing: wet asphalt, roadside sign, ice machine, bin, moon and treeline.
## Added on top of the generated exterior; it does not alter the Blender-built shell.
const MeshArt = preload("res://scenes/opening/opening_mesh.gd")
const TreeArt = preload("res://scenes/opening/roadside_trees.gd")
const StoreArt = preload("res://scenes/opening/storefront_art.gd")
const SIGN_RED := Color(0.62, 0.07, 0.06)
const BOARD_CREAM := Color(0.8, 0.74, 0.6)
const LOT_ASPHALT = preload("res://assets/materials/opening/route9_night_asphalt.png")
var _water_finish: ShaderMaterial

func _ready() -> void:
	name = "ExteriorDressing"
	_build_puddles()
	_build_pole_sign()
	_build_ice_machine()
	_build_bin()
	_build_sky()
	_dress_store_sign()
	_build_storefront_trim()
	_build_reference_window_cards()
	_build_entrance_sign()

func _mat(color: Color, rough := 0.8, metallic := 0.0, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metallic
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emit
	return m

func _box(size: Vector3, pos: Vector3, material: Material, solid := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	add_child(mi)
	if solid:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
		body.position = pos
		add_child(body)
	return mi

func _label(text: String, pos: Vector3, size: int, pixel: float, color: Color, italic := false, unshaded := true) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = pos
	label.font_size = size
	label.pixel_size = pixel
	label.modulate = color
	label.outline_size = 0
	label.shaded = not unshaded
	label.double_sided = false
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var font := preload("res://assets/fonts/original/marlow.fnt")
	var variation := FontVariation.new()
	variation.base_font = font
	if italic:
		variation.variation_transform = Transform2D(Vector2(1, 0), Vector2(-0.22, 1), Vector2.ZERO)
	label.font = variation
	add_child(label)
	return label

func _build_puddles() -> void:
	# Three drainage depressions, not a transparent veil spread over the lot.
	# Each polygon's outline is real geometry. Only the soft boundary is blended.
	var water := MeshArt.new()
	# Patch placement follows the low parking depressions that catch the real
	# canopy fixtures from arrival, not long transparent rectangles on their edges.
	_append_puddle(water,Vector2(-2.11,14.74),Vector2(1.88,1.57),1)
	_append_puddle(water,Vector2(.89,12.65),Vector2(1.18,1.05),3)
	_append_puddle(water,Vector2(-5.29,13.89),Vector2(1.08,1.29),6)
	_water_finish = ShaderMaterial.new()
	_water_finish.shader = preload("res://scenes/world/wet_reflection.gdshader")
	_water_finish.set_shader_parameter("asphalt",LOT_ASPHALT)
	water.attach(self,"Three standing-water depressions",_water_finish)

func bind_store_circuit(grid: PowerGrid) -> void:
	var sync := func(): _water_finish.set_shader_parameter("windows_lit",grid.powered("lights"))
	grid.changed.connect(sync)
	sync.call()

func _append_puddle(water, at: Vector2, radius: Vector2, phase: int) -> void:
	var rim: Array[Vector3] = []
	var uv: Array[Vector2] = []
	for i in 18:
		var angle := TAU*float(i)/18.0
		var r := 1.0+.17*sin(angle*3.0+float(phase))+.09*cos(angle*5.0-float(phase))
		var unit := Vector2(cos(angle),sin(angle))*r
		rim.append(Vector3(at.x+unit.x*radius.x,-.116,at.y+unit.y*radius.y))
		uv.append(Vector2(.5+unit.x*.37,.5+unit.y*.37))
	var core := Vector3(at.x,-.116,at.y)
	var opaque := Color(1,1,1,1)
	var edge := Color(1,1,1,0)
	for i in 18:
		var j := (i+1)%18
		var near_i := core.lerp(rim[i],.83)
		var near_j := core.lerp(rim[j],.83)
		var uv_i := Vector2(.5,.5).lerp(uv[i],.83)
		var uv_j := Vector2(.5,.5).lerp(uv[j],.83)
		water.triangle(core,near_j,near_i,Vector2(.5,.5),uv_j,uv_i)
		water.triangle_colors(near_i,near_j,rim[i],uv_i,uv_j,uv[i],opaque,opaque,edge)
		water.triangle_colors(near_j,rim[j],rim[i],uv_j,uv[j],uv[i],opaque,edge,edge)

func _build_pole_sign() -> void:
	var steel := _mat(Color(0.05, 0.055, 0.06), 0.6, 0.6)
	var origin := Vector3(-11.4, 0.0, 10.4)
	for dx in [-0.8, 0.8]:
		_box(Vector3(0.12, 3.4, 0.12), origin + Vector3(dx, 1.6, 0), steel, true)
	_box(Vector3(2.1, 1.25, 0.14), origin + Vector3(0, 3.0, 0), _mat(BOARD_CREAM.darkened(0.15), 0.8, 0.0, 0.35))
	_box(Vector3(1.9, 0.07, 0.02), origin + Vector3(0, 2.72, 0.08), _mat(SIGN_RED, 0.7, 0.0, 0.4))
	_label("Marlow's\nMarket", origin + Vector3(0, 3.18, 0.085), 78, 0.0045, SIGN_RED, true)
	_box(Vector3(2.1, 0.8, 0.14), origin + Vector3(0, 2.0, 0), _mat(Color(0.2, 0.2, 0.2), 0.7, 0.0, 0.08))

func _build_ice_machine() -> void:
	var body := _mat(Color(0.5, 0.52, 0.5), 0.55, 0.3)
	var pos := Vector3(7.7, 0.62, 6.55)
	_box(Vector3(0.95, 1.24, 0.6), pos, body, true)
	_box(Vector3(0.95, 0.12, 0.62), pos + Vector3(0, 0.66, 0), _mat(Color(0.4, 0.42, 0.4), 0.5, 0.4))
	_label("ICE", pos + Vector3(0, -0.05, 0.31), 120, 0.004, Color(0.55, 0.12, 0.1), false, false)

func _build_bin() -> void:
	var pos := Vector3(5.9, 0.43, 6.5)
	_box(Vector3(0.52, 0.86, 0.52), pos, _mat(Color(0.2, 0.19, 0.14), 0.85), true)
	_box(Vector3(0.58, 0.08, 0.58), pos + Vector3(0, 0.47, 0), _mat(Color(0.15, 0.14, 0.1), 0.8))

func _build_entrance_sign() -> void:
	var at := Vector3(1.7, 2.85, 6.13)
	_box(Vector3(.88,.23,.07), at, _mat(Color("#3c4235"), .9, 0.0, .18))
	_label("ENTRANCE", at + Vector3(0,0,.041), 36, .0034, Color("#ece0b8"))
	var housing := _mat(Color("#555349"))
	var lens := _mat(Color("#e9ce9e"), .75, 0.0, .72)
	for x in [-6.0,-2.0,1.7]:
		_box(Vector3(.62,.07,.24), Vector3(x,3.07,7.0), housing)
		_box(Vector3(.54,.018,.17), Vector3(x,3.027,7.0), lens)

func _build_sky() -> void:
	# A faint horizon glow so the treeline reads as a silhouette.
	var sky := GradientTexture2D.new()
	sky.fill = GradientTexture2D.FILL_LINEAR
	sky.fill_from = Vector2(0.5, 1.0)
	sky.fill_to = Vector2(0.5, 0.0)
	sky.gradient = Gradient.new()
	sky.gradient.colors = PackedColorArray([Color(0.05, 0.075, 0.1, 0.85), Color(0.05, 0.075, 0.1, 0.0)])
	var sky_mat := StandardMaterial3D.new()
	sky_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sky_mat.albedo_texture = sky
	sky_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sky_mat.disable_fog = true
	var backdrop := MeshInstance3D.new()
	var back_mesh := QuadMesh.new()
	back_mesh.size = Vector2(900, 90)
	backdrop.mesh = back_mesh
	backdrop.material_override = sky_mat
	backdrop.position = Vector3(0, 18.0, -90.0)
	backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(backdrop)
	var trees := TreeArt.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var poses: Array = [[],[],[]]
	for row in 2:
		for i in 27:
			var x := -53.0+i*4.1+rng.randf_range(-1.4,1.4)
			var z := -24.0-rng.randf_range(0,8)-row*12.0
			var at := Vector3(x,-.245,z)
			poses[rng.randi_range(0,2)].append(trees.pose(rng,at,rng.randf_range(6.0,13.0)))
	for kind in 3:
		trees.batch(self,poses[kind],kind,"Store woodline %d" % kind)

func _dress_store_sign() -> void:
	for node in get_parent().find_children("*","Label3D",false,false):
		var label := node as Label3D
		if label.text == "MARLOW'S  MARKET":
			StoreArt.fascia(self,label,false)
			return

func _build_storefront_trim() -> void:
	# Deeper façade faces wrap the glass that already owns collision; the entrance
	# still uses the original two animated leaves, transom, threshold, and jamb.
	var walls := MeshArt.new()
	var brick := StoreArt.frontage_brick()
	walls.box(Vector3(-8.81,1.55,6.135),Vector3(.30,3.1,.29),Rect2(0,0,.3,3.1))
	walls.box(Vector3(-6.39,1.55,6.135),Vector3(.27,3.1,.25),Rect2(0,0,.27,3.1))
	walls.box(Vector3(.680,1.55,6.120),Vector3(.24,3.1,.27),Rect2(0,0,.24,3.1))
	walls.box(Vector3(2.693,1.55,6.120),Vector3(.25,3.1,.26),Rect2(0,0,.25,3.1))
	walls.box(Vector3(-4.02,.283,6.128),Vector3(9.37,.566,.25),Rect2(0,0,9.37,.566))
	walls.box(Vector3(5.91,.283,6.128),Vector3(6.12,.566,.25),Rect2(0,0,6.12,.566))
	walls.box(Vector3(6.265,1.68,6.105),Vector3(5.41,2.296,.228),Rect2(0,0,5.41,2.30))
	walls.box(Vector3(0,2.834,6.130),Vector3(18.0,.235,.28),Rect2(0,0,18,.235))
	walls.attach(self,"Raised brick window piers lintel and skirt",brick)

	var sills := MeshArt.new()
	var concrete := MeshArt.material(StoreArt.PLASTER)
	concrete.albedo_color = Color("#c8b8a1")
	for pair in [[-7.60,2.03],[-2.87,6.57],[3.18,.91]]:
		sills.box(Vector3(pair[0],.608,6.147),Vector3(pair[1],.093,.33),Rect2(0,0,pair[1],.32))
	sills.box(Vector3(-7.58,1.135,6.281),Vector3(1.92,.075,.455),Rect2(0,0,1.9,.7))
	sills.attach(self,"Cast-stone sills and projecting coffee counter",concrete)

	var bronze := MeshArt.material(StoreArt.PLASTER)
	bronze.albedo_color = Color("#777259")
	var frame := MeshArt.new()
	for x in [-8.61,-6.56,-6.22,-4.10,-1.70,.545,2.831,3.63]:
		frame.box(Vector3(x,1.66,6.181),Vector3(.077,2.10,.128))
	for pair in [[-7.59,2.11],[-2.84,6.78],[3.22,.88]]:
		frame.box(Vector3(pair[0],.655,6.184),Vector3(pair[1],.041,.113))
		frame.box(Vector3(pair[0],2.69,6.184),Vector3(pair[1],.071,.125))
	frame.box(Vector3(-7.59,1.88,6.182),Vector3(2.11,.06,.134))
	# Separate deep perimeter casing never crosses the open path.
	for x in [.809,2.591]:
		frame.box(Vector3(x,1.365,6.20),Vector3(.063,2.73,.23))
	frame.box(Vector3(1.70,2.745,6.20),Vector3(1.84,.08,.23))
	frame.attach(self,"Bronze window mullions and double-door surround",bronze)

	var service := MeshArt.new()
	var dark := _mat(Color("#372e26"))
	service.box(Vector3(-7.62,1.088,6.151),Vector3(1.98,.105,.208))
	service.box(Vector3(-7.76,1.443,5.934),Vector3(.43,.54,.33))
	service.box(Vector3(-7.76,1.688,6.062),Vector3(.32,.095,.24))
	service.box(Vector3(-7.76,1.239,6.056),Vector3(.32,.052,.176))
	service.attach(self,"Coffee service opening and original brewer",dark)

	var steel := MeshArt.new()
	steel.box(Vector3(-7.76,1.657,6.195),Vector3(.349,.035,.039))
	steel.box(Vector3(-7.76,1.427,6.142),Vector3(.056,.111,.028))
	steel.box(Vector3(-7.76,1.324,6.177),Vector3(.145,.027,.092))
	steel.attach(self,"Coach-lit chrome brewer face",StoreArt.warm(Color("#9c825a"),.21))
	var cups := MeshArt.new()
	var paper := StoreArt.warm(Color("#dec99f"),.26)
	for i in 3:
		var cup := Vector3(-7.26+float(i)*.113,1.201+float(i%2)*.026,6.184)
		cups.box(cup,Vector3(.067,.121+float(i%2)*.051,.067))
		cups.box(cup+Vector3(0,.059+float(i%2)*.027,0),Vector3(.077,.012,.077))
	cups.attach(self,"Stacks of paper coffee cups",paper)

	var entry := MeshArt.new()
	var rubber := _mat(Color("#302d28"),.9)
	entry.box(Vector3(1.7,.007,6.91),Vector3(1.92,.012,.72),Rect2(0,0,2,1))
	entry.attach(self,"Recessed entrance scraper mat",rubber)

# Window signage does not alter the shell, its ray setup or entrance.
func _build_reference_window_cards() -> void:
	var plates := MeshArt.new()
	var coffee_spot := Vector3(-7.59,2.152,6.222)
	var sale_spot := Vector3(-2.20,1.22,6.15)
	plates.box(coffee_spot,Vector3(1.94,.414,.043))
	plates.box(sale_spot,Vector3(.77,.79,.030),Rect2(0,0,1,1),
		Transform3D(Basis(Vector3.FORWARD,.045),sale_spot-Basis(Vector3.FORWARD,.045)*sale_spot))
	var old_card := MeshArt.material(StoreArt.PLASTER)
	old_card.albedo_color = Color("#e6d4a7")
	old_card.emission_enabled = true
	old_card.emission = Color("#c39354")
	old_card.emission_energy_multiplier = .17
	plates.attach(self,"Coffee placard and weekly specials card",old_card)
	_label("COFFEE",coffee_spot+Vector3(-.145,0,.027),72,.0039,Color("#47392b"))
	_label("WEEKLY\nSPECIALS",sale_spot+Vector3(0,0,.026),47,.0033,Color("#484138")).rotation.z = .045
	var cup := MeshArt.new()
	var pos := coffee_spot+Vector3(.48,0,.029)
	cup.box(pos,Vector3(.166,.097,.014))
	cup.box(pos+Vector3(.102,.012,0),Vector3(.047,.012,.014))
	cup.box(pos+Vector3(.125,-.015,0),Vector3(.014,.057,.014))
	cup.box(pos+Vector3(.102,-.042,0),Vector3(.05,.013,.014))
	cup.box(pos-Vector3(0,.067,0),Vector3(.225,.015,.015))
	cup.attach(self,"Coffee cup mark",_mat(Color("#4a3a29")))
