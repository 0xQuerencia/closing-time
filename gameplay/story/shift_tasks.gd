class_name ShiftTasks
extends Node3D
## The shift's physical chores: restock three gaps, bag the trash, check the rear latch.
signal restocked(count: int)
signal trash_bagged
signal trash_placed
signal latch_lifted
signal latch_locked
signal latch_unlocked
const STOCK_IDS := ["crisps", "cola", "noodles"]
const SLOT_POINTS := [Vector3(-6.33, 1.14, 1.98), Vector3(-3.33, 1.14, 1.98), Vector3(-0.33, 1.14, 1.98)]
const CARTON_POINT := Vector3(5.75, 0.36, 1.35)
const BIN_POINT := Vector3(-8.55, 0.0, 5.3)
const BAG_SPOT := Vector3(4.25, 0.0, -5.2)
const LATCH_POINT := Vector3(4.25, 1.02, -5.86)
var game: Gameplay
var slots: Array[RestockSlot] = []
var filled := 0
var taken := 0
var bag_made := false
var bag_placed := false
var latch_is_lifted := false
var locked := false
## Everything fixed to the rear door's inside face, so it can ride on the leaf when the door swings.
var latch_parts: Array[Node3D] = []
var door_ajar := Callable()  # true while the rear door is open: the lock cannot be worked then
var _lever: Node3D
var _key: Node3D
var _placed: Array[Product] = []
var _bin: TrashBin

func build(owner_game: Gameplay) -> ShiftTasks:
	game = owner_game
	name = "ShiftTasks"
	game.world.add_child(self)
	var carton := StockCarton.new()
	carton.tasks = self
	carton.position = CARTON_POINT
	_box_collider(carton, Vector3(0.7, 0.5, 0.5))
	add_child(carton)
	for point in SLOT_POINTS:
		var slot := RestockSlot.new()
		slot.position = point
		slot.tasks = self
		slot.build()
		add_child(slot)
		slots.append(slot)
	_build_bin()
	_build_bag_spot()
	_build_latch()
	return self

func _box_collider(body: Node3D, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)

func take_stock(actor: Node) -> bool:
	if actor.held != null:
		return false
	var product := game.spawn_product(STOCK_IDS[taken % STOCK_IDS.size()], null)
	taken += 1
	return actor.pick_up(product)

func stock_slot(slot: RestockSlot, product: Product) -> bool:
	if slot.filled:
		return false
	slot.filled = true
	product.place_at(slot.global_position, 0.0)
	product.enabled = false
	_placed.append(product)
	slot.ghost.visible = false
	filled += 1
	restocked.emit(filled)
	return true

func _build_bin() -> void:
	_bin = TrashBin.new()
	_bin.tasks = self
	_bin.position = BIN_POINT
	_bin.build()
	add_child(_bin)

func make_bag(actor: Node) -> bool:
	if bag_made or actor.held != null:
		return false
	bag_made = true
	var bag := game.spawn_product("trash_bag", null)
	actor.pick_up(bag)
	trash_bagged.emit()
	return true

func _build_bag_spot() -> void:
	var spot := BagSpot.new()
	spot.tasks = self
	spot.position = BAG_SPOT
	_box_collider(spot, Vector3(0.6, 0.12, 0.5))
	spot.get_child(0).position.y = 0.06
	add_child(spot)
	var marker := MeshInstance3D.new()
	var plate := BoxMesh.new()
	plate.size = Vector3(0.72, 0.012, 0.58)
	marker.mesh = plate
	marker.position = BAG_SPOT + Vector3(0, 0.009, 0)
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.52, 0.38, 0.17)
	paint.roughness = 0.9
	marker.material_override = paint
	add_child(marker)
	var label := Label3D.new()
	label.text = "TRASH PICKUP"
	label.font_size = 32
	label.pixel_size = 0.0018
	label.modulate = Color(0.92, 0.78, 0.48)
	label.shaded = false
	label.rotation.x = -PI / 2.0
	label.position = BAG_SPOT + Vector3(0, 0.018, 0)
	add_child(label)

func place_bag(product: Product) -> bool:
	if bag_placed or product.product_id != "trash_bag":
		return false
	bag_placed = true
	product.place_at(Vector3(BAG_SPOT.x - 0.12, 0.0, BAG_SPOT.z), 0.4)
	product.enabled = false
	_placed.append(product)
	trash_placed.emit()
	if game.interactor != null:
		game.interactor.message.emit("Bag left at the TRASH PICKUP mark. Checklist updated.")
	return true

func _build_latch() -> void:
	var lever_base := LatchLever.new()
	lever_base.tasks = self
	lever_base.position = LATCH_POINT
	_box_collider(lever_base, Vector3(0.36, 0.08, 0.1))
	add_child(lever_base)
	latch_parts.append(lever_base)
	add_child(_prop("latch_plate", LATCH_POINT))
	_lever = _prop("latch_lever", LATCH_POINT + Vector3(-0.13, 0, 0.03))  # pivots at its left end
	add_child(_lever)
	var key_lock := LatchKey.new()
	key_lock.tasks = self
	key_lock.position = LATCH_POINT + Vector3(0, -0.13, 0)
	_box_collider(key_lock, Vector3(0.12, 0.12, 0.08))
	add_child(key_lock)
	latch_parts.append(key_lock)
	_key = _prop("latch_key", LATCH_POINT + Vector3(0, -0.13, 0.0345))
	add_child(_key)

## One of the latch's low-poly pieces, nearest-filtered like everything else, riding the door with the rest.
func _prop(file: String, at: Vector3) -> Node3D:
	var model := (load("res://assets/models/props/%s.glb" % file) as PackedScene).instantiate() as Node3D
	model.position = at
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		for i in (mi as MeshInstance3D).get_surface_override_material_count():
			var m := (mi as MeshInstance3D).get_active_material(i) as BaseMaterial3D
			if m != null:
				m = m.duplicate() as BaseMaterial3D
				m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				(mi as MeshInstance3D).set_surface_override_material(i, m)
	latch_parts.append(model)
	return model

func _latch_sound(kind: String) -> void:
	if is_inside_tree() and not latch_parts.is_empty():
		Foley.play_at(latch_parts[0], kind, (latch_parts[0] as Node3D).global_position, -9.0)

## Chores undone: stocked items removed, bag back in the bin, latch down and unlocked.
func reset() -> void:
	for product in _placed:
		if is_instance_valid(product):
			product.queue_free()
	_placed.clear()
	for slot in slots:
		slot.filled = false
		slot.ghost.visible = true
	filled = 0
	taken = 0
	bag_made = false
	bag_placed = false
	latch_is_lifted = false
	var was_locked := locked
	locked = false
	if was_locked:
		latch_unlocked.emit()
	_lever.rotation.z = 0.0
	_key.rotation.z = 0.0
	_bin.show_bag()

## Put the chores back as they were at a checkpoint (shelves stocked, bag out, latch locked).
func restore(filled_count: int, bag_out: bool, latch_on: bool) -> void:
	reset()
	for i in mini(filled_count, slots.size()):
		var product := game.spawn_product(STOCK_IDS[taken % STOCK_IDS.size()], null)
		taken += 1
		stock_slot(slots[i], product)
	if bag_out:
		bag_made = true
		bag_placed = true
		_bin._stub.visible = false
	if latch_on:
		latch_is_lifted = true
		locked = true
		_lever.rotation.z = 0.0
		_key.rotation.z = -PI / 2.0
		latch_locked.emit()

func is_door_open() -> bool:
	return door_ajar.is_valid() and door_ajar.call()

func lift_latch() -> bool:
	if latch_is_lifted or locked:
		return false
	latch_is_lifted = true
	create_tween().tween_property(_lever, "rotation:z", 0.7, 0.25)
	_latch_sound("latch")
	latch_lifted.emit()
	if game.interactor != null:
		game.interactor.message.emit("Latch raised. Turn the brass lock directly below it.")
	return true

func turn_key() -> bool:
	if not latch_is_lifted or locked:
		return false
	locked = true
	var turn := create_tween()
	turn.tween_property(_key, "rotation:z", -PI / 2.0, 0.22)
	turn.tween_property(_lever, "rotation:z", 0.0, 0.2)  # the key turns, then the bar drops into the keeper
	_latch_sound("bolt")
	latch_locked.emit()
	if game.interactor != null:
		game.interactor.message.emit("Rear door locked. Latch and key are set.")
	return true

## Turn the key back: the door can open again, and one more turn locks it.
func unlock_key() -> bool:
	if not locked:
		return false
	locked = false
	latch_is_lifted = true
	var turn := create_tween()
	turn.tween_property(_key, "rotation:z", 0.0, 0.22)
	turn.tween_property(_lever, "rotation:z", 0.7, 0.2)
	_latch_sound("bolt")
	latch_unlocked.emit()
	if game.interactor != null:
		game.interactor.message.emit("Rear door unlocked. Turn the key again to relock it.")
	return true

# --- interactables for the chores ---------------------------------------------------------------

class StockCarton extends Interactable:
	var tasks: ShiftTasks
	func _init() -> void:
		super()
		display_name = "the stock carton"
		verb = "Take stock from"
		description = "Open delivery carton. Crisps, soda, noodles. The usual."
	func can_interact(actor: Node) -> bool:
		return actor.held == null
	func blocked_reason(_actor: Node) -> String:
		return "Hands full"
	func interact(actor: Node) -> void:
		tasks.take_stock(actor)
		interacted.emit(actor)

class RestockSlot extends Interactable:
	var tasks: ShiftTasks
	var filled := false
	var ghost: MeshInstance3D
	func _init() -> void:
		super()
		display_name = "shelf gap"
		verb = "Stock"
		description = "A gap in the display where something sold today."
	func build() -> void:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.18, 0.38, 0.14)
		shape.shape = box
		shape.position.y = 0.19
		add_child(shape)
		ghost = MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.17, 0.36, 0.12)
		ghost.mesh = mesh
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.96, 0.76, 0.36, 0.16)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ghost.material_override = m
		ghost.position.y = 0.19
		add_child(ghost)
	func _held_ok(actor: Node) -> bool:
		return actor.held != null and actor.held.product_id in ShiftTasks.STOCK_IDS
	func can_interact(actor: Node) -> bool:
		return not filled and _held_ok(actor)
	func blocked_reason(actor: Node) -> String:
		if filled:
			return ""
		return "Empty gap. Needs stock from the back." if actor.held == null else "That doesn't go there."
	func prompt_text(actor: Node) -> String:
		return "Stock %s" % actor.held.display_name if can_interact(actor) else ""
	func interact(actor: Node) -> void:
		var item: Product = actor.release_held()
		tasks.stock_slot(self, item)
		interacted.emit(actor)

class TrashBin extends Interactable:
	var tasks: ShiftTasks
	var _stub: Node3D
	func _init() -> void:
		super()
		display_name = "the trash bag"
		verb = "Tie off"
		description = "The bin by the counter. Full again."
	func build() -> void:
		var body := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.2
		cyl.bottom_radius = 0.17
		cyl.height = 0.62
		cyl.radial_segments = 16
		body.mesh = cyl
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.19, 0.22, 0.19)
		m.roughness = 0.88
		body.material_override = m
		body.position.y = 0.31
		add_child(body)
		var rim := MeshInstance3D.new()
		var rim_mesh := CylinderMesh.new()
		rim_mesh.top_radius = 0.215
		rim_mesh.bottom_radius = 0.215
		rim_mesh.height = 0.045
		rim_mesh.radial_segments = 16
		rim.mesh = rim_mesh
		rim.position.y = 0.61
		rim.material_override = _bin_material(Color(0.29, 0.31, 0.27))
		add_child(rim)
		var liner := MeshInstance3D.new()
		var liner_mesh := CylinderMesh.new()
		liner_mesh.top_radius = 0.185
		liner_mesh.bottom_radius = 0.15
		liner_mesh.height = 0.49
		liner_mesh.radial_segments = 12
		liner.mesh = liner_mesh
		liner.position.y = 0.39
		liner.material_override = _bin_material(Color(0.34, 0.35, 0.31))
		add_child(liner)
		for i in range(10):
			var rib := MeshInstance3D.new()
			var rib_mesh := BoxMesh.new()
			rib_mesh.size = Vector3(0.012, 0.43, 0.025)
			rib.mesh = rib_mesh
			rib.position = Vector3(0, 0.31, 0.174)
			rib.rotation.y = TAU * float(i) / 10.0
			rib.material_override = _bin_material(Color(0.25, 0.28, 0.24))
			add_child(rib)
		_stub = Node3D.new()
		_stub.name = "Tied bag in bin"
		var puff := SphereMesh.new()
		puff.radius = 0.16
		puff.height = 0.34
		puff.radial_segments = 10
		puff.rings = 5
		var bag := StandardMaterial3D.new()
		bag.albedo_color = Color(0.2, 0.21, 0.2)
		bag.roughness = 0.9
		var sack := MeshInstance3D.new()
		sack.mesh = puff
		sack.material_override = bag
		sack.scale = Vector3(1.05, 0.85, 0.85)
		_stub.add_child(sack)
		var neck := MeshInstance3D.new()
		var neck_mesh := CylinderMesh.new()
		neck_mesh.top_radius = 0.025
		neck_mesh.bottom_radius = 0.065
		neck_mesh.height = 0.12
		neck_mesh.radial_segments = 8
		neck.mesh = neck_mesh
		neck.position.y = 0.17
		neck.material_override = bag
		_stub.add_child(neck)
		var knot := MeshInstance3D.new()
		var knot_mesh := SphereMesh.new()
		knot_mesh.radius = 0.035
		knot_mesh.height = 0.06
		knot_mesh.radial_segments = 8
		knot.mesh = knot_mesh
		knot.position.y = 0.24
		knot.material_override = _bin_material(Color(0.31, 0.32, 0.29))
		_stub.add_child(knot)
		_stub.position.y = 0.65
		add_child(_stub)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.44, 0.8, 0.44)
		shape.shape = box
		shape.position.y = 0.4
		add_child(shape)
		var wall := StaticBody3D.new()  # solid to the player
		var wall_shape := CollisionShape3D.new()
		var wall_box := BoxShape3D.new()
		wall_box.size = Vector3(0.4, 0.8, 0.4)
		wall_shape.shape = wall_box
		wall_shape.position.y = 0.4
		wall.add_child(wall_shape)
		add_child(wall)
	func _bin_material(color: Color) -> StandardMaterial3D:
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.9
		return material
	func show_bag() -> void:
		_stub.visible = true
	func can_interact(actor: Node) -> bool:
		return not tasks.bag_made and actor.held == null
	func blocked_reason(actor: Node) -> String:
		if tasks.bag_made:
			return ""
		return "Hands full"
	func interact(actor: Node) -> void:
		if tasks.make_bag(actor):
			_stub.visible = false
		interacted.emit(actor)

class BagSpot extends Interactable:
	var tasks: ShiftTasks
	func _init() -> void:
		super()
		display_name = "rear door"
		verb = "Leave the bag by the"
		description = "Where the trash waits for the morning pickup."
	func can_interact(actor: Node) -> bool:
		return not tasks.bag_placed and actor.held != null and actor.held.product_id == "trash_bag"
	func prompt_text(actor: Node) -> String:
		return "Place bag on the TRASH PICKUP mark" if can_interact(actor) else ""
	func blocked_reason(_actor: Node) -> String:
		return "" if tasks.bag_placed else "Trash goes here once it's bagged."
	func interact(actor: Node) -> void:
		var item: Product = actor.release_held()
		tasks.place_bag(item)
		interacted.emit(actor)

class LatchLever extends Interactable:
	var tasks: ShiftTasks
	func _init() -> void:
		super()
		display_name = "the rear door latch"
		verb = "Lift the latch"
		description = "The latch sticks. Lift it before you turn the key."
	func can_interact(_actor: Node) -> bool:
		return not tasks.latch_is_lifted and not tasks.locked and not tasks.is_door_open()
	func blocked_reason(_actor: Node) -> String:
		if tasks.is_door_open():
			return "Close the door first."
		return "Rear door locked" if tasks.locked else "Latch is up"
	func interact(actor: Node) -> void:
		tasks.lift_latch()
		interacted.emit(actor)

class LatchKey extends Interactable:
	var tasks: ShiftTasks
	func _init() -> void:
		super()
		display_name = "the rear door lock"
		verb = "Turn the key in"
		description = "A worn brass lock. It binds unless the latch is lifted."
	func can_interact(_actor: Node) -> bool:
		return (tasks.latch_is_lifted or tasks.locked) and not tasks.is_door_open()
	func blocked_reason(_actor: Node) -> String:
		if tasks.is_door_open():
			return "Close the door first."
		return "Stuck. Lift the latch first."
	func prompt_text(actor: Node) -> String:
		if not can_interact(actor):
			return ""
		return "Unlock the rear door" if tasks.locked else "Turn the brass key"
	func interact(actor: Node) -> void:
		if tasks.locked:
			tasks.unlock_key()
		else:
			tasks.turn_key()
		interacted.emit(actor)
