extends Node3D
## Geometry follows the existing drive spline. All authored additions are visual.

const MeshArt = preload("res://scenes/opening/opening_mesh.gd")
const TreeArt = preload("res://scenes/opening/roadside_trees.gd")
const StoreArt = preload("res://scenes/opening/storefront_art.gd")
const ASPHALT = preload("res://assets/materials/opening/route9_asphalt.png")
const AGGREGATE = preload("res://assets/materials/opening/route9_aggregate.png")
const CENTER_LINE := -1.54
const ROAD_LEFT := -5.37
const ROAD_RIGHT := 2.29
const SAFFRON := Color("#b39558")
const CHALK := Color("#bfc0ab")

var center_at: Callable
var origin_t := 0.0
var foliage := TreeArt.new()
var rng := RandomNumberGenerator.new()
var wet := MeshArt.material(ASPHALT,.5)
var earth := MeshArt.material(AGGREGATE,.91)
var road_paint := MeshArt.material(null,.69)
var reflector := MeshArt.material(null,.42)

func build(spline: Callable) -> void:
	center_at = spline
	rng.seed = 20061124
	for finish in [wet,earth,road_paint,reflector]:
		finish.vertex_color_use_as_albedo = true
		finish.vertex_color_is_srgb = true
	wet.metallic_specular = .55
	reflector.emission_enabled = true
	reflector.emission = Color("#cda56b")
	reflector.emission_energy_multiplier = .13
	_environment()
	for start in range(-32,512,32):
		_section(float(start))
	for start in range(-32,512,64):
		_grove(float(start))
	origin_t = 0
	_sign("OLD ROUTE 9\nTHROUGH TRAFFIC: USE BYPASS",130.0,false)
	_sign("MARLOW'S MARKET\nOPEN UNTIL MIDNIGHT",385.0,true)
	_bridge()
	var market := Node3D.new()
	market.name = "Marlow's roadside frontage"
	market.position = Vector3(center_at.call(456.0)+18.6,-.23,-459.0)
	market.rotation.y = -.48
	add_child(market)
	StoreArt.distant_market(market)

func _environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#0a1422")
	sky_material.sky_horizon_color = Color("#27343d")
	sky_material.sky_curve = .22
	sky_material.ground_bottom_color = Color("#161d24")
	sky_material.ground_horizon_color = sky_material.sky_horizon_color
	sky_material.sun_angle_max = 0.0
	var sky := Sky.new()
	sky.sky_material = sky_material
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#929d9e")
	env.ambient_light_energy = .59
	env.fog_enabled = true
	env.fog_light_color = Color("#28353d")
	env.fog_density = .0067
	env.fog_sky_affect = 0.0
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)

func _section(start: float) -> void:
	var section := _chunk("Road surfaces",start)
	var asphalt := MeshArt.new()
	var gravel := MeshArt.new()
	var lines := MeshArt.new()
	var studs := MeshArt.new()
	var road_x := [ROAD_LEFT,-4.45,-3.0,CENTER_LINE,-.76,.69,ROAD_RIGHT]
	var tread := [Color("#b3b6b5"),Color("#e5e6e4"),Color("#dadbd8"),
		Color("#bfc0be"),Color("#e3e5e0"),Color("#e3e4e2"),Color("#a9adab")]
	for i in range(8):
		var a := start + 4.0*i
		var b := a+4.0
		for col in road_x.size()-1:
			var shade: Color = tread[col].lerp(tread[col+1],.5)
			_strip(asphalt,a,b,road_x[col],road_x[col+1],0.0,0.0,shade,3.2)
		for side in [-1.0,1.0]:
			var road_edge := ROAD_LEFT if side < 0.0 else ROAD_RIGHT
			var bands := [0.0,.77,1.82,2.84,5.4,10.0,21.0,37.0]
			var colors := [Color("#a8a398"),Color("#696f5e"),Color("#4f5748"),
				Color("#626b55"),Color("#69745c"),Color("#677056"),Color("#5a604c")]
			for band in bands.size()-1:
				var x0: float = road_edge+side*bands[band]
				var x1: float = road_edge+side*bands[band+1]
				_terrain_strip(gravel,a,b,minf(x0,x1),maxf(x0,x1),colors[band])
	for segment in range(16):
		var t := start+segment*2.0
		for edge_x in [ROAD_LEFT+.16,ROAD_RIGHT-.15]:
			_worn_line(lines,t,t+2.0,edge_x,.087,CHALK)
	for index in 4:
		var t := start + index*8.0
		_worn_line(lines,t+.55,t+3.59,CENTER_LINE,.104,SAFFRON)
		for side in [-1.0,1.0]:
			var x: float = ROAD_LEFT+.24 if side < 0 else ROAD_RIGHT-.24
			_strip(studs,t+6.93,t+7.00,x-.028,x+.028,.025,.025,CHALK,1.0)
		_strip(studs,t+4.85,t+4.948,CENTER_LINE-.043,CENTER_LINE+.043,.027,.027,SAFFRON,1.0)
	_visible(asphalt.attach(section,"Wet asphalt and tire tracks",wet),155)
	_visible(gravel.attach(section,"Shoulders, ditch and embankments",earth),155)
	_visible(lines.attach(section,"Broken paint",road_paint),120)
	_visible(studs.attach(section,"Cat's-eyes",reflector),100)

func _chunk(label: String, start: float) -> Node3D:
	var chunk := Node3D.new()
	chunk.name = "%s %d m" % [label,int(start)]
	origin_t = start
	chunk.position.z = -start
	add_child(chunk)
	return chunk

func _strip(art: RefCounted, a: float, b: float, x0: float, x1: float, y0: float, y1: float,
		shade: Color, repeat_size: float) -> void:
	art.quad(_point(a,x0,y0),_point(a,x1,y1),_point(b,x1,y1),_point(b,x0,y0),
		Rect2(x0/repeat_size,-b/repeat_size,(x1-x0)/repeat_size,(b-a)/repeat_size),shade)

func _terrain_strip(art: RefCounted, a: float, b: float, x0: float, x1: float, shade: Color) -> void:
	art.quad(_point(a,x0,_height(a,x0)),_point(a,x1,_height(a,x1)),
		_point(b,x1,_height(b,x1)),_point(b,x0,_height(b,x0)),
		Rect2(x0/3.0,-b/3.0,(x1-x0)/3.0,(b-a)/3.0),shade)

func _point(t: float, offset: float, height: float) -> Vector3:
	return Vector3(center_at.call(t)+offset,height,origin_t-t)

func _height(t: float, offset: float) -> float:
	var d := maxf(ROAD_LEFT-offset,offset-ROAD_RIGHT)
	var swell := sin(t*.113+offset*.17)*.43 + sin(t*.26)*.12
	if d <= .77:
		return lerpf(0,-.12,clampf(d/.77,0.0,1.0))
	if d < 2.84:
		return lerpf(-.12,-.69+sin(t*.082)*.11,(d-.77)/2.07)
	var bank := lerpf(-.69+sin(t*.082)*.11, .92+swell, smoothstep(2.84,7.9,d))
	var cleared := smoothstep(409.0,430.0,t)*(1.0-smoothstep(481.0,507.0,t))
	return lerpf(bank,-.38,cleared*smoothstep(2.8,7.2,offset))

func _worn_line(art: RefCounted, a: float, b: float, offset: float, width: float, color: Color) -> void:
	var t := a
	while t < b:
		var end := minf(t + rng.randf_range(.28,.74),b)
		var jitter := rng.randf_range(-.016,.016)
		var y := .012 + rng.randf_range(0,.002)
		var span := width*rng.randf_range(.74,1.0)
		_strip(art,t,end,offset+jitter-span*.5,offset+jitter+span*.5,y,y,
			color.darkened(rng.randf_range(.0,.34)),1.0)
		t = end + rng.randf_range(.025,.115)

func _grove(start: float) -> void:
	var chunk := _chunk("Roadside trees",start)
	var poses: Array = [[],[],[]]
	for side in [-1.0,1.0]:
		for row in 2:
			for slot in range(8):
				var t := start+slot*8.0+rng.randf_range(.3,7.7)
				if side > 0 and t > 344.0 and t < 504.0 and row == 0:
					continue
				var edge := ROAD_LEFT if side < 0 else ROAD_RIGHT
				var setback := rng.randf_range(4.7,9.9) if row == 0 else rng.randf_range(13.0,30.0)
				if side > 0 and t > 356.0 and t < 500.0:
					setback += 24.0
				var x: float = edge+side*setback
				var kind := rng.randi_range(0,2)
				poses[kind].append(foliage.pose(rng,_point(t,x,_height(t,x)-.13),rng.randf_range(4.1,10.2)))
	for kind in 3:
		foliage.batch(chunk,poses[kind],kind,"Tree stand %d" % kind)
	for group in chunk.get_children():
		_visible(group,180)

func _visible(instance: GeometryInstance3D, distance: float) -> void:
	instance.visibility_range_end = distance

func _sign(body: String, t: float, warm: bool) -> void:
	var at := _point(t,ROAD_RIGHT+2.0,1.60)
	var sign_node := Node3D.new()
	sign_node.position = at
	sign_node.rotation.y = -.16
	add_child(sign_node)
	var art := MeshArt.new()
	for side in [-1.0,1.0]:
		art.box(Vector3(side*.72,-1.04,0),Vector3(.079,2.24,.082))
	var post := MeshArt.material(AGGREGATE,.91)
	post.albedo_color = Color("#787d71")
	art.attach(sign_node,"Road sign posts",post)
	var plate := MeshArt.new()
	plate.box(Vector3.ZERO,Vector3(2.10,.72,.074))
	var board := MeshArt.material(AGGREGATE)
	board.albedo_color = Color("#716752") if warm else Color("#425c53")
	plate.attach(sign_node,"Weathered sign board",board)
	var label := Label3D.new()
	label.text = body
	label.font = StoreArt.FONT
	label.font_size = 40
	label.pixel_size = .0021
	label.position.z = .039
	label.modulate = Color("#d9c29a") if warm else Color("#c9d0b5")
	label.outline_size = 0
	label.shaded = false
	label.double_sided = false
	sign_node.add_child(label)

func _bridge() -> void:
	var rail := MeshArt.new()
	for start in [61.0,246.0]:
		for i in range(7):
			var t: float = start+i*2.4
			rail.box(_point(t,ROAD_LEFT-.62,.29),Vector3(.093,.86,.11))
			if i > 0:
				var a := _point(t-2.4,ROAD_LEFT-.62,.516)
				var b := _point(t,ROAD_LEFT-.62,.516)
				var center := (a+b)*.5
				var yaw := atan2(b.x-a.x,b.z-a.z)
				var orientation := Transform3D(Basis(Vector3.UP,yaw),center)
				rail.box(Vector3.ZERO,Vector3(.115,.21,a.distance_to(b)+.024),Rect2(0,0,1,1),orientation)
	var steel := MeshArt.material(AGGREGATE,.60)
	steel.albedo_color = Color("#a0a79c")
	rail.attach(self,"Galvanized culvert rails",steel)
	var driveway := MeshArt.new()
	driveway.quad(_point(433.6,ROAD_RIGHT,.006),_point(428.5,11.8,-.08),
		_point(441.4,11.8,-.08),_point(442.5,ROAD_RIGHT,.006),Rect2(0,0,5,3))
	driveway.attach(self,"Paved market driveway",wet)
