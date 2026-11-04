class_name ExteriorDressing
extends Node3D
## Night-lot dressing: wet asphalt, roadside sign, ice machine, bin, moon and treeline.
## Added on top of the generated exterior; it does not alter the Blender-built shell.
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
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["DejaVu Sans", "Liberation Sans", "sans-serif"])
	font.font_weight = 800
	var variation := FontVariation.new()
	variation.base_font = font
	if italic:
		variation.variation_transform = Transform2D(Vector2(1, 0), Vector2(-0.22, 1), Vector2.ZERO)
	label.font = variation
	add_child(label)
	return label

func _build_puddles() -> void:
	var puddle := _mat(Color(0.012, 0.016, 0.02), 0.04)
	puddle.metallic_specular = 1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 4417
	for i in 14:
		var quad := MeshInstance3D.new()
		var mesh := QuadMesh.new()
		mesh.size = Vector2(rng.randf_range(1.6, 4.4), rng.randf_range(1.0, 2.6))
		quad.mesh = mesh
		quad.material_override = puddle
		quad.rotation = Vector3(-PI / 2.0, rng.randf_range(-0.5, 0.5), 0)
		quad.position = Vector3(rng.randf_range(-10.0, 10.0), -0.112, rng.randf_range(9.5, 21.0))
		quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(quad)
	# Warm window glow smeared across the wet asphalt, like the reference stills.
	var glow := GradientTexture2D.new()
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5, 0.0)
	glow.fill_to = Vector2(0.5, 1.0)
	glow.gradient = Gradient.new()
	glow.gradient.colors = PackedColorArray([Color(1.0, 0.88, 0.6, 0.11), Color(1.0, 0.88, 0.6, 0.0)])
	var glow_mat := StandardMaterial3D.new()
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.albedo_texture = glow
	glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	for x in [-7.7, -5.3, -2.9, -0.4, 3.0]:
		var streak := MeshInstance3D.new()
		var mesh := QuadMesh.new()
		mesh.size = Vector2(2.4, 5.0)
		streak.mesh = mesh
		streak.material_override = glow_mat
		streak.rotation = Vector3(-PI / 2.0, 0, 0)
		streak.position = Vector3(x, -0.105, 10.4)
		streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(streak)

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

func _build_sky() -> void:
	var halo := GradientTexture2D.new()
	halo.fill = GradientTexture2D.FILL_RADIAL
	halo.fill_from = Vector2(0.5, 0.5)
	halo.fill_to = Vector2(1.0, 0.5)
	halo.gradient = Gradient.new()
	halo.gradient.offsets = PackedFloat32Array([0.0, 0.2, 0.24, 0.55, 1.0])
	halo.gradient.colors = PackedColorArray([Color(0.78, 0.82, 0.9, 1), Color(0.7, 0.75, 0.86, 1), Color(0.5, 0.58, 0.72, 0.5), Color(0.2, 0.26, 0.38, 0.14), Color(0.1, 0.14, 0.22, 0)])
	var moon_mat := StandardMaterial3D.new()
	moon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	moon_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	moon_mat.albedo_texture = halo
	moon_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	moon_mat.disable_fog = true
	var moon := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(26, 26)
	moon.mesh = quad
	moon.material_override = moon_mat
	moon.position = Vector3(-26.0, 40.0, -80.0)
	moon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(moon)
	# A faint horizon glow so the treeline reads as a silhouette.
	var sky := GradientTexture2D.new()
	sky.fill = GradientTexture2D.FILL_LINEAR
	sky.fill_from = Vector2(0.5, 1.0)
	sky.fill_to = Vector2(0.5, 0.0)
	sky.gradient = Gradient.new()
	sky.gradient.colors = PackedColorArray([Color(0.05, 0.075, 0.1, 1), Color(0.018, 0.03, 0.045, 1)])
	var sky_mat := StandardMaterial3D.new()
	sky_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sky_mat.albedo_texture = sky
	sky_mat.disable_fog = true
	var backdrop := MeshInstance3D.new()
	var back_mesh := QuadMesh.new()
	back_mesh.size = Vector2(320, 70)
	backdrop.mesh = back_mesh
	backdrop.material_override = sky_mat
	backdrop.position = Vector3(0, 26.0, -90.0)
	backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(backdrop)
	var tree := StandardMaterial3D.new()
	tree.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tree.albedo_color = Color(0.004, 0.007, 0.009)
	tree.disable_fog = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for i in 70:
		var cone := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		var h := rng.randf_range(12.0, 22.0)
		mesh.top_radius = 0.0
		mesh.bottom_radius = h * 0.2
		mesh.height = h
		cone.mesh = mesh
		cone.material_override = tree
		cone.position = Vector3(-95.0 + i * 2.8 + rng.randf_range(-1.0, 1.0), h * 0.5 - 2.0, rng.randf_range(-62.0, -48.0))
		cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(cone)

## Cream fascia board with red italic lettering and a red stripe, lit by two wall lamps.
func _dress_store_sign() -> void:
	for node in get_parent().find_children("*", "Label3D", false, false):
		var label := node as Label3D
		if label.text != "MARLOW'S  MARKET":
			continue
		label.modulate = SIGN_RED
		label.position.z += 0.05
		var variation := FontVariation.new()
		var base := SystemFont.new()
		base.font_names = PackedStringArray(["DejaVu Sans", "Liberation Sans", "sans-serif"])
		base.font_weight = 800
		variation.base_font = base
		variation.variation_transform = Transform2D(Vector2(1, 0), Vector2(-0.2, 1), Vector2.ZERO)
		label.font = variation
		var text_px := variation.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size)
		var width := text_px.x * label.pixel_size + 0.9
		var center := label.position - Vector3(0, 0, 0.05)
		var board := _box(Vector3(width, 1.05, 0.06), center + Vector3(0, 0.0, 0.0), _mat(BOARD_CREAM.darkened(0.12), 0.8, 0.0, 0.22))
		board.name = "SignBoard"
		_box(Vector3(width, 0.08, 0.07), center + Vector3(0, -0.4, 0.0), _mat(SIGN_RED, 0.7, 0.0, 0.25))
		for dx in [-width * 0.33, width * 0.33]:
			var lamp_pos: Vector3 = center + Vector3(dx, 0.78, 0.22)
			_box(Vector3(0.34, 0.07, 0.14), lamp_pos, _mat(Color(0.05, 0.05, 0.05), 0.6, 0.5))
			var spot := SpotLight3D.new()
			spot.position = lamp_pos
			spot.rotation.x = -1.15
			spot.spot_range = 4.5
			spot.spot_angle = 50.0
			spot.light_energy = 1.8
			spot.light_color = Color(1.0, 0.92, 0.75)
			add_child(spot)
