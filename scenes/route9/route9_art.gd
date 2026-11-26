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
# Stand centers and radii are in metres along the spline and out from the road edge.
const BEND_STANDS := [
	[40.0,-10.0,13.0,6.3,9,4.0,8.8], [65.5,-7.7,12.0,4.6,14,4.1,9.7],
	[88.0,-14.4,14.0,9.0,12,4.8,10.6], [116.0,-8.3,14.0,5.0,19,4.5,10.6],
	[139.0,-9.5,15.0,6.5,17,4.2,10.0], [159.0,-20.0,16.0,8.8,9,5.0,10.1],
	[53.0,9.1,15.0,5.3,14,4.7,9.0], [76.5,13.3,12.7,7.1,11,3.8,8.8],
	[95.0,22.5,19.0,7.4,8,4.4,9.5], [117.0,25.0,13.1,5.6,8,4.4,8.0],
	[142.0,10.6,12.7,5.9,14,3.7,8.7], [158.0,18.0,15.9,8.3,10,4.9,9.2],
]
# Foreground anchors shape the two driver sightlines and the open ditch between them.
const BEND_TREES := [
	[54.2,4.7,6.9,1], [59.5,-4.5,8.0,0], [74.6,6.6,7.9,0], [84.2,-5.3,6.7,2],
	[91.8,6.3,6.2,1], [107.7,-4.8,8.5,0], [115.6,-5.8,6.8,1], [124.1,7.6,6.2,2],
	[128.7,-4.8,8.8,2], [132.4,-5.7,7.1,1], [135.6,5.6,5.2,1], [142.3,6.4,7.6,0],
]
const GRAVEL := Color("#898277")
const SEDGE := Color("#686d56")
const LOAM := Color("#5d6051")

var center_at: Callable
var origin_t := 0.0
var foliage := TreeArt.new(true)
var rng := RandomNumberGenerator.new()
var wet := MeshArt.material(ASPHALT,.5)
var earth := MeshArt.material(AGGREGATE,.91)
var road_paint := MeshArt.material(null,.69)

func build(spline: Callable) -> void:
	center_at = spline
	rng.seed = 20061124
	for finish in [wet,earth,road_paint]:
		finish.vertex_color_use_as_albedo = true
		finish.vertex_color_is_srgb = true
	wet.metallic_specular = .55
	_environment()
	for start in range(-32,512,32):
		_section(float(start))
	_groves()
	origin_t = 0
	_sign("OLD ROUTE 9\nUSE BYPASS",130.0,false)
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
	var road_x := [ROAD_LEFT,-4.45,-3.0,CENTER_LINE,-.76,.69,ROAD_RIGHT]
	var tread := [Color("#b3b6b5"),Color("#e5e6e4"),Color("#dadbd8"),
		Color("#bfc0be"),Color("#e3e5e0"),Color("#e3e4e2"),Color("#a9adab")]
	var left := _terrain_row(start,-1.0)
	var right := _terrain_row(start,1.0)
	for i in range(8):
		var a := start + 4.0*i
		var b := a+4.0
		for col in road_x.size()-1:
			var shade: Color = tread[col].lerp(tread[col+1],.5)
			_strip(asphalt,a,b,road_x[col],road_x[col+1],0.0,0.0,shade,3.2)
		var next_left := _terrain_row(b,-1.0)
		var next_right := _terrain_row(b,1.0)
		_terrain_strip(gravel,left,next_left,true)
		_terrain_strip(gravel,right,next_right,false)
		left = next_left
		right = next_right
	if start == 96.0:
		_patch_edge(asphalt)
	for segment in range(16):
		var t := start+segment*2.0
		_worn_line(lines,t,t+2.0,ROAD_LEFT+.16,.087,CHALK)
		if t < 114.0 or t >= 122.0:
			_worn_line(lines,t,t+2.0,ROAD_RIGHT-.15,.087,CHALK)
	for index in 4:
		var t := start + index*8.0
		_worn_line(lines,t+.55,t+3.59,CENTER_LINE,.104,SAFFRON)
		for side in [-1.0,1.0]:
			var x: float = ROAD_LEFT+.24 if side < 0 else ROAD_RIGHT-.24
			_strip(lines,t+6.93,t+7.00,x-.028,x+.028,.025,.025,CHALK,1.0)
		_strip(lines,t+4.85,t+4.948,CENTER_LINE-.043,CENTER_LINE+.043,.027,.027,SAFFRON,1.0)
	_visible(asphalt.attach(section,"Wet asphalt and tire tracks",wet),155)
	_visible(gravel.attach(section,"Shoulders, ditch and embankments",earth),155)
	_visible(lines.attach(section,"Broken paint and cat's-eyes",road_paint),120)

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

func _terrain_strip(art: RefCounted, near_row: Array, far_row: Array, left: bool) -> void:
	var near_points: PackedVector3Array = near_row[0]
	var far_points: PackedVector3Array = far_row[0]
	var near_colors: PackedColorArray = near_row[1]
	var far_colors: PackedColorArray = far_row[1]
	for i in near_points.size()-1:
		var lo := i+1 if left else i
		var hi := i if left else i+1
		var a := near_points[lo]
		var b := near_points[hi]
		var c := far_points[hi]
		var d := far_points[lo]
		var uv_a := Vector2(a.x,a.z-origin_t)/3.3
		var uv_b := Vector2(b.x,b.z-origin_t)/3.3
		var uv_c := Vector2(c.x,c.z-origin_t)/3.3
		var uv_d := Vector2(d.x,d.z-origin_t)/3.3
		art.triangle_colors(a,b,c,uv_a,uv_b,uv_c,near_colors[lo],near_colors[hi],far_colors[hi])
		art.triangle_colors(a,c,d,uv_a,uv_c,uv_d,near_colors[lo],far_colors[hi],far_colors[lo])

func _point(t: float, offset: float, height: float) -> Vector3:
	return Vector3(center_at.call(t)+offset,height,origin_t-t)

func _ground_profile(t: float, side: float) -> Array:
	var swale := _stretch(t,88.0,106.0,123.0,138.0) if side > 0.0 else 0.0
	var cut := _stretch(t,97.0,113.0,125.0,144.0) if side < 0.0 else 0.0
	var rise := sin(t*.099+side)*.30 + sin(t*.225+side)*.16
	var crest := .78+rise+cut*1.05-swale*.93
	var bottom := -.41+sin(t*.082+side)*.11-swale*.29
	var bands := PackedFloat32Array([0.0,.50+sin(t*.23+side)*.13,
		1.67+sin(t*.17+side)*.32+swale*.67,3.51+sin(t*.16)*.47+swale*.93,
		5.5+sin(t*.105+side)*.78+swale*1.65,9.1+sin(t*.123)*1.04+swale*1.8,
		18.0+sin(t*.10+side)*3.0,37.0])
	var heights := PackedFloat32Array([0.0,-.055,bottom,bottom+.16,
		crest*.67-.23,crest,crest*.60+sin(t*.07+side)*.64+swale*.71,.31+rise])
	if side > 0.0:
		var lot := _stretch(t,409.0,430.0,481.0,507.0)
		bands[-1] += 19.0*_stretch(t,336.0,356.0,500.0,516.0)
		for i in range(2,bands.size()):
			heights[i] = lerpf(heights[i],-.38,lot*smoothstep(.5,4.9,bands[i]))
	return [bands,heights]

func _stretch(t: float, start: float, full: float, taper: float, end: float) -> float:
	return smoothstep(start,full,t)*(1.0-smoothstep(taper,end,t))

func _terrain_row(t: float, side: float) -> Array:
	var profile := _ground_profile(t,side)
	var bands: PackedFloat32Array = profile[0]
	var heights: PackedFloat32Array = profile[1]
	var points := PackedVector3Array()
	var colors := PackedColorArray()
	var edge := ROAD_LEFT if side < 0.0 else ROAD_RIGHT
	for i in bands.size():
		var d := bands[i]
		points.append(_point(t,edge+side*d,heights[i]))
		var clay := .35+.31*sin(t*.132+d*.43+side)+.14*sin(t*.281-d*.68)
		var shade := SEDGE.lerp(LOAM,clay)
		colors.append(shade.lerp(GRAVEL,(1.0-smoothstep(.12,2.0,d))*.94))
	return [points,colors]

func _height(t: float, offset: float) -> float:
	var side := -1.0 if offset < ROAD_LEFT else 1.0
	var d := ROAD_LEFT-offset if side < 0.0 else offset-ROAD_RIGHT
	var a := floorf(t/4.0)*4.0
	return lerpf(_profile_height(a,side,d),_profile_height(a+4.0,side,d),(t-a)/4.0)

func _profile_height(t: float, side: float, d: float) -> float:
	var profile := _ground_profile(t,side)
	var bands: PackedFloat32Array = profile[0]
	var heights: PackedFloat32Array = profile[1]
	for i in range(1,bands.size()):
		if d < bands[i]:
			return lerpf(heights[i-1],heights[i],clampf(inverse_lerp(bands[i-1],bands[i],d),0.0,1.0))
	return heights[-1]

func _patch_edge(art: RefCounted) -> void:
	var edge := [[109.8,2.23],[112.9,1.86],[115.4,2.01],[117.1,1.53],
		[120.4,1.76],[122.7,1.90],[124.1,2.26]]
	for i in edge.size()-1:
		var a: float = edge[i][0]
		var b: float = edge[i+1][0]
		var lip_a: float = edge[i][1]
		var lip_b: float = edge[i+1][1]
		art.quad(_point(a,lip_a,.008),_point(a,ROAD_RIGHT,.008),
			_point(b,ROAD_RIGHT,.008),_point(b,lip_b,.008),
			Rect2(lip_a/3.2,-b/3.2,(ROAD_RIGHT-lip_a)/3.2,(b-a)/3.2),Color("#9da6a5"))
		art.quad(_point(a,lip_a-.027,.009),_point(a,lip_a,.009),
			_point(b,lip_b,.009),_point(b,lip_b-.027,.009),Rect2(.1,-b/3.2,.014,(b-a)/3.2),Color("#747a77"))

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

func _groves() -> void:
	var groups := {}
	var occupied: Array[Vector2] = []
	for start in range(-32,512,64):
		groups[start] = [[],[],[]]
	for tree in BEND_TREES:
		_place_tree(groups,tree[0],tree[1],tree[2],tree[3])
		occupied.append(Vector2(tree[0],tree[1]))
	for stand in BEND_STANDS:
		var count := 0
		for attempt in stand[4]*3:
			var angle := rng.randf_range(0.0,TAU)
			var radius := sqrt(rng.randf())
			var point := Vector2(stand[0]+cos(angle)*radius*stand[2],stand[1]+sin(angle)*radius*stand[3])
			if occupied.any(func(trunk: Vector2) -> bool: return trunk.distance_squared_to(point) < 3.24):
				continue
			var crown := rng.randf()
			var kind := 0 if crown < .55 else (1 if crown < .93 else 2)
			_place_tree(groups,point.x,point.y,rng.randf_range(stand[5],stand[6]),kind)
			occupied.append(point)
			count += 1
			if count == stand[4]:
				break
	for start: int in groups:
		for side in [-1.0,1.0]:
			for row in 2:
				for slot in 8:
					var t := start+slot*8.0+rng.randf_range(.3,7.7)
					if (t > 25.0 and t < 172.0) or (side > 0.0 and t > 344.0 and t < 504.0 and row == 0):
						continue
					if row == 1 and slot % 3 == 1:
						continue
					var setback := rng.randf_range(5.4,12.4) if row == 0 else rng.randf_range(14.0,30.0)
					if side > 0.0 and t > 356.0 and t < 500.0:
						setback += 24.0
					var crown := rng.randf()
					var kind := 0 if crown < .52 else (1 if crown < .93 else 2)
					_place_tree(groups,t,side*setback,rng.randf_range(4.1,10.2),kind)
		var chunk := _chunk("Roadside trees",float(start))
		for kind in 3:
			foliage.batch(chunk,groups[start][kind],kind,"Tree stand %d" % kind)
		for group in chunk.get_children():
			_visible(group,180)

func _place_tree(groups: Dictionary, t: float, setback: float, height: float, kind: int) -> void:
	var start := floori((t+32.0)/64.0)*64-32
	var x := (ROAD_LEFT if setback < 0.0 else ROAD_RIGHT)+setback
	var at := Vector3(center_at.call(t)+x,_height(t,x)-.10,start-t)
	groups[start][kind].append(foliage.pose(rng,at,height))

func _visible(instance: GeometryInstance3D, distance: float) -> void:
	instance.visibility_range_end = distance

func _sign(body: String, t: float, warm: bool) -> void:
	var at := _point(t,ROAD_RIGHT+2.0,1.60 if warm else 1.16)
	var sign_node := Node3D.new()
	sign_node.position = at
	sign_node.rotation.y = -.16
	add_child(sign_node)
	var art := MeshArt.new()
	if warm:
		for side in [-1.0,1.0]:
			art.box(Vector3(side*.72,-1.04,0),Vector3(.079,2.24,.082))
	else:
		art.box(Vector3(0,-.64,-.015),Vector3(.065,1.90,.072))
	var post := MeshArt.material(AGGREGATE,.91)
	post.albedo_color = Color("#787d71")
	art.attach(sign_node,"Road sign posts",post)
	var plate := MeshArt.new()
	plate.box(Vector3.ZERO,Vector3(2.10,.72,.074) if warm else Vector3(.93,.49,.038))
	var board := MeshArt.material(AGGREGATE)
	board.albedo_color = Color("#716752") if warm else Color("#596657")
	plate.attach(sign_node,"Weathered sign board",board)
	var label := Label3D.new()
	label.text = body
	label.font = StoreArt.FONT
	label.font_size = 40
	label.pixel_size = .0021 if warm else .0018
	label.position.z = .039 if warm else .020
	label.modulate = Color("#d9c29a") if warm else Color("#c9d0b5")
	label.outline_size = 0
	label.shaded = false
	label.double_sided = false
	sign_node.add_child(label)
	if not warm:
		for detail in sign_node.get_children():
			_visible(detail,100)

func _bridge() -> void:
	var rail := MeshArt.new()
	var steel := MeshArt.material(AGGREGATE,.60)
	steel.albedo_color = Color("#909991")
	_rail(rail,246.0,ROAD_LEFT-.62,7)
	rail.attach(self,"Far guardrail",steel)
	var bend := _chunk("Culvert crossing",112.0)
	var bend_rail := MeshArt.new()
	_rail(bend_rail,112.2,ROAD_RIGHT+.74,6)
	_visible(bend_rail.attach(bend,"Weathered W-beam",steel),105)
	_culvert(bend,118.0,ROAD_RIGHT+2.38)
	origin_t = 0.0
	var driveway := MeshArt.new()
	driveway.quad(_point(433.6,ROAD_RIGHT,.006),_point(428.5,11.8,-.08),
		_point(441.4,11.8,-.08),_point(442.5,ROAD_RIGHT,.006),Rect2(0,0,5,3))
	driveway.attach(self,"Paved market driveway",wet)

func _rail(art: RefCounted, start: float, x: float, posts: int) -> void:
	var last := Vector3.ZERO
	for i in posts:
		var t := start+i*2.4
		var offset := x
		var top := .53
		if i == 0 or i == posts-1:
			offset += .20 if x > 0.0 else -.20
			top -= .09
		var foot := _height(t,offset)-.08
		var here := _point(t,offset,top)
		art.box(_point(t,offset,(top+foot)*.5),Vector3(.124,top-foot,.096))
		if i > 0:
			var axis := (here-last).normalized()
			var basis := Basis.looking_at(axis)
			var pose := Transform3D(basis,(here+last)*.5)
			for rib in [-.049,.049]:
				art.box(Vector3(0,rib,0),Vector3(.104,.069,here.distance_to(last)+.018),Rect2(0,0,1,1),pose)
			art.box(Vector3.ZERO,Vector3(.059,.084,here.distance_to(last)+.018),Rect2(0,0,1,1),pose)
		last = here

func _culvert(parent: Node3D, t: float, x: float) -> void:
	var masonry := MeshArt.new()
	var mouth := _point(t,x,_height(t,x)+.016)
	var inner := .32
	var outer := .49
	for i in 8:
		var a := PI*i/8.0
		var b := PI*(i+1)/8.0
		var u := Vector3(cos(a),sin(a),0)
		var v := Vector3(cos(b),sin(b),0)
		var recess := Vector3(0,0,-.19)
		masonry.quad(mouth+u*outer,mouth+v*outer,mouth+v*inner,mouth+u*inner,
			Rect2(0,0,.4,.4),Color("#919086").darkened(.018*(i%3)))
		masonry.quad(mouth+u*inner,mouth+v*inner,mouth+v*inner+recess,mouth+u*inner+recess,
			Rect2(0,0,.4,.4),Color("#555c50"))
		masonry.triangle(mouth+recess,mouth+u*inner+recess,mouth+v*inner+recess,
			Vector2.ZERO,Vector2.RIGHT,Vector2.UP,Color("#252c29"))
	_visible(masonry.attach(parent,"Concrete drain mouth",earth),75)
