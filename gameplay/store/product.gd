class_name Product
extends Interactable
## A physical store product: can be picked up, carried, placed, inspected and scanned.
signal placed(product: Product)
var product_id := ""
var def: Dictionary
var scanned := false
var checkout: Checkout
var holder: Node
var home_root: Node3D
var _shape: CollisionShape3D

func setup(id: String, root: Node3D) -> Product:
	product_id = id
	def = ProductCatalog.get_def(id)
	home_root = root
	display_name = def.name
	verb = "Pick up"
	name = "Product_" + id
	_build()
	return self

func price() -> int:
	return def.price

func _build() -> void:
	var size: Vector3 = def.size
	if product_id != "trash_bag" and _build_detailed(size):
		return
	var body := MeshInstance3D.new()
	var band := MeshInstance3D.new()
	if def.shape == "can":
		var cyl := CylinderMesh.new()
		cyl.top_radius = size.x / 2.0
		cyl.bottom_radius = size.x / 2.0
		cyl.height = size.y
		body.mesh = cyl
		var ring := CylinderMesh.new()
		ring.top_radius = size.x / 2.0 + 0.0008
		ring.bottom_radius = size.x / 2.0 + 0.0008
		ring.height = size.y * 0.42
		band.mesh = ring
		_shape = CollisionShape3D.new()
		var cs := CylinderShape3D.new()
		cs.radius = size.x / 2.0 + 0.01
		cs.height = size.y
		_shape.shape = cs
	elif def.shape == "sack":
		var lump := SphereMesh.new()
		lump.radius = size.x / 2.0
		lump.height = size.y * 1.6
		body.mesh = lump
		body.scale = Vector3(1.0, 0.62, size.z / size.x)
		var knot := SphereMesh.new()
		knot.radius = 0.045
		knot.height = 0.09
		band.mesh = knot
		_shape = CollisionShape3D.new()
		var ss := BoxShape3D.new()
		ss.size = size + Vector3.ONE * 0.02
		_shape.shape = ss
	else:
		var box := BoxMesh.new()
		box.size = size
		body.mesh = box
		var strip := BoxMesh.new()
		strip.size = Vector3(size.x + 0.002, size.y * 0.4, size.z + 0.002)
		band.mesh = strip
		_shape = CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size + Vector3.ONE * 0.02
		_shape.shape = bs
	body.material_override = _material(def.color, 0.55)
	band.material_override = _material(def.band, 0.7)
	body.position.y = size.y / 2.0
	band.position.y = size.y + 0.02 if def.shape == "sack" else size.y / 2.0
	_shape.position.y = size.y / 2.0
	add_child(body)
	add_child(band)
	add_child(_shape)

func _material(color: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m

func can_interact(actor: Node) -> bool:
	if not enabled:
		return false
	if checkout != null:
		return checkout.can_scan(self)
	return holder == null and (actor == null or not "held" in actor or actor.held == null)

func blocked_reason(actor: Node) -> String:
	if checkout != null:
		return "%s — already scanned" % display_name if scanned else ""
	if holder != null:
		return ""
	if actor != null and "held" in actor and actor.held != null:
		return "Hands full"
	return ""

func prompt_text(actor: Node) -> String:
	if not can_interact(actor):
		return ""
	return ("Scan %s  %s" if checkout != null else "Pick up %s  %s") % [display_name, ProductCatalog.price_text(price())]

func interact(actor: Node) -> void:
	if checkout != null:
		checkout.scan(self)
	elif actor != null and actor.has_method("pick_up"):
		actor.pick_up(self)
	interacted.emit(actor)

func inspect(actor: Node) -> String:
	inspected.emit(actor)
	return "%s — %s. %s" % [display_name, ProductCatalog.price_text(price()), def.blurb]

## Carried by a player or NPC: no collision, parented to the carrier.
func attach_to(parent: Node3D, local_pos: Vector3) -> void:
	holder = parent
	_shape.disabled = true
	if get_parent():
		reparent(parent, false)
	else:
		parent.add_child(self)
	position = local_pos
	rotation = Vector3.ZERO

func place_at(world_pos: Vector3, yaw: float) -> void:
	holder = null
	_shape.disabled = false
	if get_parent():
		reparent(home_root, false)
	else:
		home_root.add_child(self)
	global_position = world_pos
	rotation = Vector3(0, yaw, 0)
	placed.emit(self)

# --- detailed models ------------------------------------------------------------------------------

func _solid(color: Color, rough := 0.6, metal := 0.0) -> StandardMaterial3D:
	var m := _material(color, rough)
	m.metallic = metal
	return m

func _cyl(top: float, bottom: float, height: float, y: float, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 16
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position.y = y
	add_child(mi)
	return mi

func _slab(size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	add_child(mi)
	return mi

func _collider(size: Vector3) -> void:
	_shape = CollisionShape3D.new()
	if def.shape == "can":
		var cyl := CylinderShape3D.new()
		cyl.radius = size.x / 2.0 + 0.01
		cyl.height = size.y
		_shape.shape = cyl
	else:
		var box := BoxShape3D.new()
		box.size = size + Vector3.ONE * 0.02
		_shape.shape = box
	_shape.position.y = size.y / 2.0
	add_child(_shape)

## Real-looking shapes for the products that are held up close. Returns false for ids without one.
func _build_detailed(size: Vector3) -> bool:
	var r := size.x / 2.0
	var h := size.y
	match product_id:
		"cup_coffee":
			_cyl(r * 1.08, r * 0.74, h, h * 0.5, _solid(Color(0.92, 0.9, 0.84), 0.8))
			_cyl(r * 1.1, r * 0.92, h * 0.34, h * 0.46, _solid(Color(0.5, 0.3, 0.16), 0.95))
			_cyl(r * 1.16, r * 1.1, h * 0.06, h + 0.004, _solid(Color(0.12, 0.09, 0.07), 0.5))
			_cyl(r * 0.96, r * 1.1, h * 0.06, h + 0.04 * h, _solid(Color(0.14, 0.1, 0.08), 0.5))
			_slab(Vector3(r * 0.5, 0.004, r * 0.3), Vector3(r * 0.2, h + 0.052 * h, 0.0), _solid(Color(0.05, 0.04, 0.03), 0.4))
		"cola":
			_cyl(r, r, h * 0.94, h * 0.5, _solid(Color(0.55, 0.05, 0.05), 0.3, 0.35))
			_cyl(r * 1.01, r * 1.01, h * 0.34, h * 0.5, _solid(Color(0.9, 0.87, 0.78), 0.55))
			_cyl(r * 0.86, r, h * 0.04, h * 0.985, _solid(Color(0.75, 0.76, 0.78), 0.25, 0.9))
			_cyl(r, r * 0.86, h * 0.04, h * 0.015, _solid(Color(0.7, 0.72, 0.74), 0.3, 0.9))
			_slab(Vector3(r * 0.9, 0.002, r * 0.5), Vector3(0, h * 1.004, 0), _solid(Color(0.8, 0.8, 0.82), 0.25, 0.9))
		"water":
			var plastic := _solid(Color(0.6, 0.78, 0.88, 0.55), 0.15)
			plastic.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_cyl(r * 0.86, r, h * 0.66, h * 0.35, plastic)
			_cyl(r * 0.28, r * 0.86, h * 0.2, h * 0.78, plastic)
			_cyl(r * 0.3, r * 0.3, h * 0.07, h * 0.94, _solid(Color(0.85, 0.88, 0.9), 0.5))
			_cyl(r * 0.36, r * 0.36, h * 0.07, h * 0.98, _solid(Color(0.1, 0.34, 0.65), 0.5))
			_cyl(r * 0.9, r * 1.01, h * 0.26, h * 0.36, _solid(Color(0.12, 0.3, 0.22), 0.7))
		"coffee":
			_cyl(r * 0.9, r, h * 0.8, h * 0.4, _solid(Color(0.18, 0.1, 0.05), 0.35))
			_cyl(r * 0.91, r * 1.01, h * 0.34, h * 0.4, _solid(Color(0.78, 0.55, 0.16), 0.6))
			_cyl(r * 0.96, r * 0.96, h * 0.2, h * 0.9, _solid(Color(0.06, 0.05, 0.05), 0.45))
		"noodles":
			_cyl(r * 1.1, r * 0.76, h * 0.95, h * 0.47, _solid(Color(0.78, 0.28, 0.1), 0.7))
			_cyl(r * 1.14, r * 1.12, h * 0.06, h * 0.97, _solid(Color(0.92, 0.88, 0.7), 0.7))
			_cyl(r * 1.06, r * 1.06, h * 0.03, h * 1.02, _solid(Color(0.85, 0.8, 0.55), 0.8))
			_cyl(r * 1.05, r * 0.78, h * 0.3, h * 0.4, _solid(Color(0.95, 0.9, 0.6), 0.8))
		"paper":
			_slab(Vector3(size.x, size.y, size.z), Vector3(0, size.y / 2.0, 0), _solid(Color(0.8, 0.78, 0.72), 0.95))
			_slab(Vector3(size.x * 0.96, 0.003, size.z * 0.18), Vector3(0, size.y + 0.0015, -size.z * 0.3), _solid(Color(0.08, 0.08, 0.08), 0.9))
			for i in 4:
				_slab(Vector3(size.x * 0.22, 0.002, size.z * 0.5), Vector3(-size.x * 0.35 + i * size.x * 0.23, size.y + 0.0015, size.z * 0.16), _solid(Color(0.42, 0.41, 0.4), 0.95))
			_slab(Vector3(size.x * 0.2, 0.002, size.z * 0.2), Vector3(size.x * 0.3, size.y + 0.002, size.z * 0.3), _solid(Color(0.28, 0.28, 0.27), 0.9))
		"crisps":
			_slab(Vector3(size.x, h * 0.9, size.z), Vector3(0, h * 0.5, 0), _solid(Color(0.55, 0.1, 0.07), 0.45, 0.2))
			_slab(Vector3(size.x * 0.84, h * 0.3, size.z + 0.002), Vector3(0, h * 0.5, 0), _solid(Color(0.9, 0.82, 0.55), 0.6))
			for y in [h * 0.97, h * 0.03]:
				_slab(Vector3(size.x, h * 0.05, size.z * 0.5), Vector3(0, y, 0), _solid(Color(0.7, 0.68, 0.7), 0.3, 0.7))
		_:
			return false
	_collider(size)
	return true
