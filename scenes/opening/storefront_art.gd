extends RefCounted
## The fascia is shared by the near market and the distant Route 9 frontage.

const MeshArt = preload("res://scenes/opening/opening_mesh.gd")
const ASPHALT = preload("res://assets/materials/opening/route9_asphalt.png")
const PLASTER = preload("res://assets/models/exterior_plaster.png")
const BRICK = preload("res://assets/models/shell_brick.png")
const FONT = preload("res://assets/fonts/original/marlow.fnt")
const RED := Color("#a42d25")

static func fascia(parent: Node3D, label: Label3D, distant: bool) -> void:
	var metal := MeshArt.new()
	metal.box(Vector3(0,3.35,7.99),Vector3(18.52,.30,.20))
	metal.box(Vector3(0,3.39,6.83),Vector3(18.52,.08,2.20))
	var green := MeshArt.material(PLASTER)
	green.albedo_color = Color("#45564e")
	metal.attach(parent,"Weathered green canopy flashing",green)

	var edge := MeshArt.new()
	edge.box(Vector3(0,3.201,8.053),Vector3(18.55,.082,.108))
	edge.box(Vector3(0,3.26,8.079),Vector3(18.57,.030,.063))
	for x in [-8.51,8.51]:
		edge.box(Vector3(x,.231,7.0),Vector3(.267,.46,.256))
		edge.box(Vector3(x,2.965,7.0),Vector3(.236,.248,.223))
	var edge_mat := MeshArt.material(PLASTER)
	edge_mat.albedo_color = Color("#b2a486")
	edge.attach(parent,"Canopy drip edge and post boots",edge_mat)

	label.font = FONT
	label.font_size = 80
	label.pixel_size = .008
	label.outline_size = 0
	label.modulate = RED
	label.position = Vector3(-1.2,3.69,8.173)
	label.shaded = false
	if distant:
		label.modulate = Color("#8a3123")
	var width := FONT.get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,label.font_size).x*label.pixel_size+.92
	var backing := MeshArt.new()
	backing.box(Vector3(label.position.x,3.69,8.108),Vector3(width,.81,.122))
	var enamel := MeshArt.material(PLASTER)
	enamel.albedo_color = Color("#dac9a8")
	enamel.emission_enabled = true
	enamel.emission = Color("#d9b988")
	enamel.emission_energy_multiplier = .21 if distant else .11
	backing.attach(parent,"Painted Marlow's sign board",enamel)

	var hardware := MeshArt.new()
	var lens := MeshArt.new()
	for offset in [-.348,.348]:
		var pos := Vector3(label.position.x+width*offset,4.10,8.26)
		hardware.box(pos,Vector3(.30,.092,.225))
		lens.box(pos-Vector3(0,.053,0),Vector3(.232,.024,.158))
		if not distant:
			var light := SpotLight3D.new()
			light.position = pos+Vector3(0,-.081,.11)
			light.rotation.x = -1.06
			light.spot_range = 2.7
			light.spot_angle = 55
			light.light_energy = 1.18
			light.light_color = Color("#f9d49a")
			parent.add_child(light)
	var dark := MeshArt.material(null)
	dark.albedo_color = Color("#383b34")
	hardware.attach(parent,"Sign lamp hoods",dark)
	lens.attach(parent,"Sign lamp diffusers",warm(Color("#f1d8a1"),.68))

static func warm(color: Color, intensity: float) -> StandardMaterial3D:
	var finish := MeshArt.material(null)
	finish.albedo_color = color
	finish.emission_enabled = true
	finish.emission = color
	finish.emission_energy_multiplier = intensity
	return finish

static func distant_market(parent: Node3D) -> void:
	var masonry := MeshArt.new()
	masonry.box(Vector3(0,1.61,0),Vector3(18,3.22,11.9))
	masonry.box(Vector3(0,.299,6.03),Vector3(18,.59,.18))
	masonry.box(Vector3(6.27,1.72,6.0),Vector3(5.46,2.72,.18))
	masonry.attach(parent,"Marlow's masonry silhouette",MeshArt.material(BRICK))
	var windows := MeshArt.new()
	var frames := MeshArt.new()
	var poster := MeshArt.new()
	var fixtures := MeshArt.new()
	for x in [-7.7,-5.3,-2.9,-.40,3.0,1.7]:
		var span: float = .91 if x == 3.0 else (1.35 if x == 1.7 else 2.30)
		windows.box(Vector3(x,1.609,6.098),Vector3(span,2.09,.04))
		frames.box(Vector3(x-span*.51,1.63,6.137),Vector3(.093,2.22,.105))
		if x != 1.7:
			poster.box(Vector3(x-.29,.96,6.125),Vector3(span*.37,.61,.025))
			poster.box(Vector3(x+.45,1.20,6.123),Vector3(span*.27,1.08,.023))
		else:
			frames.box(Vector3(x,1.39,6.138),Vector3(.062,2.31,.114))
		fixtures.box(Vector3(x,2.45,6.13),Vector3(span*.64,.082,.03))
	for y in [.60,2.68]:
		frames.box(Vector3(-2.7,y,6.13),Vector3(12.67,.083,.106))
	for x in [-8.5,8.5]:
		frames.box(Vector3(x,1.57,7),Vector3(.172,3.14,.186))
	frames.box(Vector3(0,3.16,6.91),Vector3(18.5,.17,2.3))
	windows.attach(parent,"Transmitted shop lights",warm(Color("#aa8960"),.50))
	poster.attach(parent,"Silhouettes of shop fixtures",warm(Color("#655542"),.23))
	fixtures.attach(parent,"Lit tube silhouettes",warm(Color("#eccc91"),.80))
	var frame := MeshArt.material(PLASTER)
	frame.albedo_color = Color("#585f56")
	frames.attach(parent,"Storefront mullions and canopy",frame)
	var label := Label3D.new()
	label.text = "MARLOW'S  MARKET"
	label.double_sided = false
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	parent.add_child(label)
	fascia(parent,label,true)

	var pool := MeshArt.new()
	pool.quad(Vector3(-11,-.065,19),Vector3(11,-.065,19),Vector3(11,-.065,6.2),Vector3(-11,-.065,6.2),Rect2(0,0,5,4))
	pool.attach(parent,"Approach asphalt",MeshArt.material(ASPHALT,.49))
	var light := OmniLight3D.new()
	light.position = Vector3(-2.7,2.8,7.2)
	light.light_color = Color("#ffcc8a")
	light.light_energy = 1.65
	light.omni_range = 13
	parent.add_child(light)
