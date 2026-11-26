class_name ExteriorDressing
extends Node3D
## Night-lot dressing: wet asphalt, roadside sign, ice machine, bin, moon and treeline.
## Added on top of the generated exterior; it does not alter the Blender-built shell.
const MeshArt = preload("res://scenes/opening/opening_mesh.gd")
const TreeArt = preload("res://scenes/opening/roadside_trees.gd")
const StoreArt = preload("res://scenes/opening/storefront_art.gd")
const SIGN_RED := Color(0.62, 0.07, 0.06)
const BOARD_CREAM := Color(0.8, 0.74, 0.6)

func _ready() -> void:
	name = "ExteriorDressing"
	_build_puddles()
	_build_pole_sign()
	_build_ice_machine()
	_build_bin()
	_build_sky()
	_dress_store_sign()
	_build_storefront_trim()
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
	var soft := GradientTexture2D.new()
	soft.fill = GradientTexture2D.FILL_RADIAL
	soft.fill_from = Vector2(0.5, 0.5)
	soft.fill_to = Vector2(1.0, 0.5)
	soft.gradient = Gradient.new()
	soft.gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	soft.gradient.colors = PackedColorArray([Color(0.01, 0.014, 0.02, 0.8), Color(0.01, 0.014, 0.02, 0.5), Color(0.01, 0.014, 0.02, 0.0)])
	var puddle := _mat(Color(1, 1, 1), 0.05)
	puddle.albedo_texture = soft
	puddle.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puddle.metallic_specular = 1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 4417
	var pools: Array[Transform3D] = []
	for i in 10:
		var pose := Basis(Vector3.RIGHT,-PI*.5).scaled(Vector3(rng.randf_range(1.6,4.6),1.0,rng.randf_range(1.1,2.8)))
		pools.append(Transform3D(pose,Vector3(rng.randf_range(-10.0,10.0),-.118,rng.randf_range(10.4,21.0))))
	_batch_water("Scattered standing water",puddle,pools)

	var glow_mat := ShaderMaterial.new()
	glow_mat.shader = preload("res://scenes/world/wet_reflection.gdshader")
	var streaks: Array[Transform3D] = []
	for x in [-7.7,-5.3,-2.9,-.4,1.7,3.0]:
		var pose := Basis(Vector3.RIGHT,-PI*.5).scaled(Vector3(rng.randf_range(.94,1.68),1.0,rng.randf_range(3.2,5.25)))
		streaks.append(Transform3D(pose,Vector3(x,-.109,rng.randf_range(10.58,10.98))))
	_batch_water("Window light on broken wet asphalt",glow_mat,streaks)

func _batch_water(label: String, finish: Material, poses: Array[Transform3D]) -> void:
	var tile := QuadMesh.new()
	tile.size = Vector2.ONE
	tile.material = finish
	var group := MultiMesh.new()
	group.transform_format = MultiMesh.TRANSFORM_3D
	group.mesh = tile
	group.instance_count = poses.size()
	for i in poses.size():
		group.set_instance_transform(i,poses[i])
	var batch := MultiMeshInstance3D.new()
	batch.name = label
	batch.multimesh = group
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(batch)

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
	var frame := MeshArt.new()
	var metal := MeshArt.material(StoreArt.PLASTER)
	metal.albedo_color = Color("#444a40")
	for x in [-8.90,-6.50,-4.10,-1.70,.88,2.39,3.55]:
		frame.box(Vector3(x,1.66,6.138),Vector3(.063,2.102,.084))
	for pair in [[-4.04,9.87],[3.0,1.13]]:
		frame.box(Vector3(pair[0],.619,6.147),Vector3(pair[1],.052,.198))
		frame.box(Vector3(pair[0],2.693,6.145),Vector3(pair[1],.036,.123))
	frame.attach(self,"Sills and shopfront glazing stops",metal)
	var apron := MeshArt.new()
	var concrete := MeshArt.material(StoreArt.PLASTER)
	concrete.albedo_color = Color("#827765")
	for pair in [[-4.14,9.78],[5.71,6.62]]:
		apron.box(Vector3(pair[0],.058,6.153),Vector3(pair[1],.105,.105))
	apron.attach(self,"Scuffed masonry kick plate",concrete)
