extends RefCounted
## Small flat-shaded mesh builder. Vertices use Godot coordinates and outward CCW order.

var surface := SurfaceTool.new()

func _init() -> void:
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

static func material(texture: Texture2D, roughness := .88) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_texture = texture
	result.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	result.roughness = roughness
	return result

static func tile(index: int) -> Rect2:
	return Rect2(Vector2(index % 4, floori(index / 4.0)) * .25 + Vector2.ONE / 256.0, Vector2.ONE * (.25 - 2.0 / 256.0))

func triangle(a: Vector3, b: Vector3, c: Vector3, uv_a: Vector2, uv_b: Vector2, uv_c: Vector2, tint := Color.WHITE) -> void:
	var normal := (b - a).cross(c - a).normalized()
	_vertex(a, normal, uv_a, tint)
	_vertex(c, normal, uv_c, tint)
	_vertex(b, normal, uv_b, tint)

func _vertex(point: Vector3, normal: Vector3, uv: Vector2, tint: Color) -> void:
	surface.set_normal(normal)
	surface.set_uv(uv)
	surface.set_color(tint)
	surface.add_vertex(point)

func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, uv := Rect2(0, 0, 1, 1), tint := Color.WHITE) -> void:
	var bottom_left := Vector2(uv.position.x, uv.end.y)
	var top_right := Vector2(uv.end.x, uv.position.y)
	triangle(a, b, c, bottom_left, uv.end, top_right, tint)
	triangle(a, c, d, bottom_left, top_right, uv.position, tint)

func box(center: Vector3, size: Vector3, uv := Rect2(0, 0, 1, 1), pose := Transform3D.IDENTITY) -> void:
	var half := size * .5
	var a := pose * (center + half * Vector3(-1,-1,1))
	var b := pose * (center + half * Vector3(1,-1,1))
	var c := pose * (center + half * Vector3(1,1,1))
	var d := pose * (center + half * Vector3(-1,1,1))
	var e := pose * (center + half * Vector3(-1,-1,-1))
	var f := pose * (center + half * Vector3(1,-1,-1))
	var g := pose * (center + half * Vector3(1,1,-1))
	var h := pose * (center + half * Vector3(-1,1,-1))
	quad(a,b,c,d,uv)
	quad(f,e,h,g,uv)
	quad(e,a,d,h,uv)
	quad(b,f,g,c,uv)
	quad(d,c,g,h,uv)
	quad(e,f,b,a,uv)

func mesh(finish: Material) -> ArrayMesh:
	surface.set_material(finish)
	surface.index()
	return surface.commit()

func attach(parent: Node3D, label: String, finish: Material, shadows := false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh(finish)
	node.add_to_group("authored_materials")
	if not shadows:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node
