class_name SetDressing
extends Node3D
## Small, deliberate signs that people work here: a receipt that curled as it cooled, a can knocked off the shelf
## beside the gap Jamie has to fill, and grime worn into the tile along the paths people actually walk.
## Visual only: nothing here can be picked up or blocks anyone.
const COUNTER_TOP := 0.955

func build(game: Gameplay) -> SetDressing:
	name = "SetDressing"
	_receipt(Vector3(-6.32, COUNTER_TOP + 0.001, 4.04), 0.5, 0.2, 21)
	_receipt(Vector3(-7.05, 0.003, 5.02), 2.2, 0.12, 5)  # one that missed the bin behind the counter
	_still_product(game, "cola", Vector3(-6.02, 0.034, 2.42), Vector3(PI / 2.0, 1.15, 0))  # knocked off beside the gap, never picked up
	_scuffs(Vector3(1.7, 0.0, 4.6), Vector2(1.5, 1.6), 3)     # the entrance mat has walked dirt onto the tile
	_scuffs(Vector3(-4.6, 0.0, 3.2), Vector2(2.0, 0.8), 7)    # where people wait at the counter
	_scuffs(Vector3(-5.9, 0.0, 5.15), Vector2(1.4, 0.6), 11)  # the clerk's spot, worn darkest
	_scuffs(Vector3(4.25, 0.0, -4.3), Vector2(0.9, 2.6), 13)  # the back hall to the rear door
	game.world.add_child(self)
	return self

## A receipt strip that curls up from the end, like thermal paper does once torn off.
func _receipt(at: Vector3, yaw: float, length: float, seed_value: int) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var width := 0.058
	var steps := 7
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var curl := rng.randf_range(0.45, 0.7)  # how far along the strip the curl starts
	var points: Array[Vector3] = []
	var angle := 0.0
	var p := Vector3.ZERO
	for i in steps + 1:
		points.append(p)
		var t := float(i) / steps
		if t > curl:
			angle += 0.62  # the end rolls up and over
		p += Vector3(0, sin(angle), cos(angle)) * (length / steps)
	for i in steps:
		var a := points[i]
		var b := points[i + 1]
		var v0 := float(i) / steps
		var v1 := float(i + 1) / steps
		var quad := [[a + Vector3(-width / 2, 0, 0), Vector2(0, v0)], [a + Vector3(width / 2, 0, 0), Vector2(1, v0)],
			[b + Vector3(width / 2, 0, 0), Vector2(1, v1)], [b + Vector3(-width / 2, 0, 0), Vector2(0, v1)]]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_uv(quad[k][1])
			st.add_vertex(quad[k][0])
	st.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.mesh = st.commit()
	var paper := StandardMaterial3D.new()
	paper.albedo_texture = _receipt_texture(rng)
	paper.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	paper.cull_mode = BaseMaterial3D.CULL_DISABLED
	paper.roughness = 0.9
	mesh.material_override = paper
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.position = at
	mesh.rotation.y = yaw
	add_child(mesh)

## 16 x 64 px: off-white paper, rows of grey print, a total line, a fold crease.
func _receipt_texture(rng: RandomNumberGenerator) -> ImageTexture:
	var img := Image.create(16, 64, false, Image.FORMAT_RGB8)
	img.fill(Color(0.86, 0.85, 0.8))
	for y in range(4, 60, 3):
		var cut := rng.randi_range(5, 13)
		for x in range(2, cut):
			if rng.randf() < 0.75:
				img.set_pixel(x, y, Color(0.42, 0.42, 0.44))
		if y % 9 == 1:
			for x in range(10, 14):
				img.set_pixel(x, y, Color(0.36, 0.36, 0.38))
	for x in 16:
		img.set_pixel(x, 30, Color(0.76, 0.75, 0.7))
	return ImageTexture.create_from_image(img)

## The real product's look, frozen in place with nothing to interact with.
func _still_product(game: Gameplay, id: String, at: Vector3, rot: Vector3) -> void:
	var source := Product.new().setup(id, game.world)
	var holder := Node3D.new()
	holder.name = "Still_" + id
	for child in source.find_children("*", "MeshInstance3D", false, false):
		source.remove_child(child)
		holder.add_child(child)
	source.free()
	holder.position = at
	holder.rotation = rot
	add_child(holder)

## Soft grime projected onto the floor; several overlapping blobs so the edge never looks like a stamp.
func _scuffs(centre: Vector3, extent: Vector2, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var texture := _grime_texture(rng)
	for i in 3:
		var decal := Decal.new()
		decal.texture_albedo = texture
		decal.size = Vector3(extent.x * rng.randf_range(0.6, 1.0), 0.3, extent.y * rng.randf_range(0.6, 1.0))
		decal.position = centre + Vector3(rng.randf_range(-0.2, 0.2) * extent.x, 0.05, rng.randf_range(-0.2, 0.2) * extent.y)
		decal.rotation.y = rng.randf_range(-0.4, 0.4)
		decal.albedo_mix = 1.0
		decal.upper_fade = 0.1
		decal.lower_fade = 0.1
		add_child(decal)

## 32 x 32 px: darker in the middle, broken up, fading to nothing at the edges.
func _grime_texture(rng: RandomNumberGenerator) -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := Vector2(x - 15.5, y - 15.5).length() / 16.0
			var a := clampf(1.0 - d, 0.0, 1.0) * rng.randf_range(0.35, 0.85)
			img.set_pixel(x, y, Color(0.12, 0.1, 0.08, a))
	var texture := ImageTexture.create_from_image(img)
	return texture
