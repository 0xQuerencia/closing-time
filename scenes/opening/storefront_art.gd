extends RefCounted
## The fascia is shared by the near market and the distant Route 9 frontage.

const MeshArt = preload("res://scenes/opening/opening_mesh.gd")
const ASPHALT = preload("res://assets/materials/opening/route9_night_asphalt.png")
const PLASTER = preload("res://assets/models/exterior_plaster.png")
const BRICK = preload("res://assets/models/shell_brick.png")
const FONT = preload("res://assets/fonts/original/marlow.fnt")
const GLYPH_ATLAS = preload("res://assets/fonts/original/marlow.png")
# Ink cells from the project's original Marlow Terminal BMFont, in atlas pixels.
const SIGN_CELLS := {
	"M": Rect2(104,20,5,7),
	"A": Rect2(8,20,5,7),
	"R": Rect2(16,30,5,7),
	"L": Rect2(96,20,5,7),
	"O": Rect2(120,20,5,7),
	"W": Rect2(56,30,5,7),
	"'": Rect2(56,0,2,7),
	"S": Rect2(24,30,5,7),
	"K": Rect2(88,20,5,7),
	"E": Rect2(40,20,5,7),
	"T": Rect2(32,30,5,7),
}
const GLYPH_METRES := .0544 # 80 pt / 10 px source size × previous Label3D pixel_size
const SIGN_FACE = preload("res://assets/materials/opening/marlow_channel_enamel.png")
const RED := Color("#a42d25")

static func fascia(parent: Node3D, label: Label3D, distant: bool) -> void:
	var metal := MeshArt.new()
	if distant:
		metal.box(Vector3(0,3.35,7.99),Vector3(18.52,.30,.20))
		metal.box(Vector3(0,3.39,6.83),Vector3(18.52,.08,2.20))
	else:
		var fascia_wall := MeshArt.new()
		fascia_wall.box(Vector3(0,3.76,7.76),Vector3(18.50,.92,.685),Rect2(0,0,18.50,.92))
		var brick := MeshArt.material(BRICK)
		brick.albedo_color = Color("#ae826d")
		fascia_wall.attach(parent,"Raised continuous brick sign parapet",brick)
		metal.box(Vector3(0,3.305,7.995),Vector3(18.70,.26,.35),Rect2(0,0,12,.35))
		metal.box(Vector3(0,3.176,6.95),Vector3(18.69,.145,2.14),Rect2(0,0,14,2.1))
	var green := MeshArt.material(PLASTER)
	green.albedo_color = Color("#45564e") if distant else Color("#9d8b6d")
	metal.attach(parent,"Weathered full-depth concrete canopy",green)

	var edge := MeshArt.new()
	edge.box(Vector3(0,3.201,8.053),Vector3(18.55,.082,.108))
	edge.box(Vector3(0,3.26,8.079),Vector3(18.57,.030,.063))
	for x in [-8.51,8.51]:
		edge.box(Vector3(x,.231,7.0),Vector3(.267,.46,.256))
		edge.box(Vector3(x,2.965,7.0),Vector3(.236,.248,.223))
	var edge_mat := MeshArt.material(PLASTER)
	edge_mat.albedo_color = Color("#b2a486")
	edge.attach(parent,"Canopy drip edge and post boots",edge_mat)

	# Individually mounted, shallow letter cans rather than the old one-piece board.
	var fitted := MeshArt.new()
	var caps := MeshArt.new()
	var lettering := MeshArt.new()
	var hardware := MeshArt.new()
	var lens := MeshArt.new()
	var width := 12.34
	var word_break := label.text.find("  ")
	for index in label.text.length():
		var glyph := label.text.substr(index,1)
		if glyph == " ":
			continue
		var compaction := (.25 if index < word_break else -.25) if word_break >= 0 else 0.0
		var center := Vector3(-1.2 + (index - (label.text.length()-1)*.5)*.72 + compaction,3.72 + (index%3-1)*.019,8.136)
		if not distant:
			center += Vector3(0,.024,.08)
		fitted.box(center-Vector3(0,0,.062),Vector3(.69,.72,.162))
		caps.box(center+Vector3(0,0,.031),Vector3(.626,.644,.079))
		var cell: Rect2 = SIGN_CELLS.get(glyph,Rect2())
		if not cell.has_area():
			continue
		var size := Vector2(GLYPH_ATLAS.get_size())
		var atlas_uv := Rect2(cell.position/size,cell.size/size)
		var ink_origin := center+Vector3(-GLYPH_METRES*.5,GLYPH_METRES,.074)
		var right := Vector3.RIGHT*cell.size.x*GLYPH_METRES*.5
		var up := Vector3.UP*cell.size.y*GLYPH_METRES*.5
		lettering.quad(ink_origin-right-up,ink_origin+right-up,ink_origin+right+up,ink_origin-right+up,atlas_uv)
	label.hide()
	var trim := MeshArt.material(PLASTER)
	trim.albedo_color = Color("#5f2721")
	fitted.attach(parent,"Marlow red-letter mountings",trim)
	var enamel := MeshArt.material(SIGN_FACE)
	enamel.emission_enabled = true
	enamel.emission = RED
	enamel.emission_energy_multiplier = .18 if distant else .23
	caps.attach(parent,"Marlow enamel channel letters",enamel)
	# Preserve the individual letter plates while drawing all 14 glyphs together.
	var ink := MeshArt.material(GLYPH_ATLAS)
	ink.albedo_color = Color("#f0dfbc") if not distant else Color("#d7bc95")
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	ink.alpha_scissor_threshold = .45
	lettering.attach(parent,"Marlow original glyphs",ink)

	for x in [-6.0,-2.0,1.7]:
		var pos := Vector3(x,3.135,7.79)
		hardware.box(pos,Vector3(1.04,.106,.172))
		lens.box(pos-Vector3(0,.052,0),Vector3(.91,.029,.121))
	for offset in [-.348,.348]:
		var pos := Vector3(-1.2+width*offset,4.09,8.26)
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
	hardware.attach(parent,"Sign hoods and canopy tube housings",dark)
	lens.attach(parent,"Sign and canopy diffusers",warm(Color("#f1d8a1"),.68))

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
