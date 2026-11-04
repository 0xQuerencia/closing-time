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
