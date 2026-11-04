class_name Checkout
extends Node3D
## Counter zone + register state machine: IDLE -> OPEN (items on counter) -> PAID -> IDLE.
enum State { IDLE, OPEN, PAID }
signal sale_opened(customer: Node)
signal item_added(product: Product)
signal item_scanned(product: Product)
signal sale_completed(transaction: Dictionary)
signal sale_closed
signal state_changed(state: State)
const ZONE_MIN := Vector2(-5.95, 3.78)  # x, z on the customer side of the counter
const ZONE_MAX := Vector2(-4.4, 4.12)
const COUNTER_TOP := 0.955
const DROP_SLOTS := [Vector3(-5.4, COUNTER_TOP, 3.95), Vector3(-5.05, COUNTER_TOP, 3.95), Vector3(-5.75, COUNTER_TOP, 3.95)]
var state := State.IDLE
var customer: Node
var items: Array[Product] = []
var history: Array[Dictionary] = []
var terminal: RegisterTerminal
var _lcd: Label3D
var _beep: AudioStreamPlayer3D
var _chime: AudioStreamPlayer3D

func build(world: Node3D) -> void:
	name = "Checkout"
	world.add_child(self)
	var top := StaticBody3D.new()
	top.name = "Countertop surface"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.25, 0.09, 0.96)
	shape.shape = box
	top.add_child(shape)
	top.position = Vector3(-6, 0.91, 4.25)
	add_child(top)
	terminal = RegisterTerminal.new()
	terminal.checkout = self
	var tshape := CollisionShape3D.new()
	var tbox := BoxShape3D.new()
	tbox.size = Vector3(0.42, 0.32, 0.1)
	tshape.shape = tbox
	terminal.add_child(tshape)
	terminal.position = Vector3(-5.8, 1.4, 4.4)
	add_child(terminal)
	_build_screen()
	_build_keypad()
	_beep = _make_player(1180.0, 70, Vector3(-5.8, 1.1, 4.3))
	_chime = _make_player(660.0, 260, Vector3(-5.8, 1.1, 4.3))
	ServiceBell.new().build(self, Vector3(-6.75, COUNTER_TOP, 3.98))
	_refresh_screen()

func _build_screen() -> void:
	var glass := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.325, 0.215)
	glass.mesh = quad
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.03, 0.075, 0.045)
	m.roughness = 0.35
	m.emission_enabled = true
	m.emission = Color(0.02, 0.06, 0.03)
	glass.material_override = m
	glass.position = Vector3(-5.8, 1.4, 4.4425)
	add_child(glass)
	_lcd = Label3D.new()
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["DejaVu Sans Mono", "Liberation Mono", "monospace"])
	_lcd.font = mono
	_lcd.pixel_size = 0.00056
	_lcd.font_size = 46
	_lcd.modulate = Color(0.62, 0.95, 0.62)
	_lcd.outline_size = 0
	_lcd.shaded = false
	_lcd.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_lcd.position = Vector3(-5.8 - 0.143, 1.4, 4.4435)
	add_child(_lcd)

## Chunky register keys on the clerk side of the screen.
func _build_keypad() -> void:
	var plate := MeshInstance3D.new()
	var plate_mesh := BoxMesh.new()
	plate_mesh.size = Vector3(0.3, 0.035, 0.17)
	plate.mesh = plate_mesh
	plate.material_override = _flat(Color(0.52, 0.48, 0.4), 0.7)
	var pad := Node3D.new()
	pad.position = Vector3(-5.8, COUNTER_TOP + 0.03, 4.62)
	pad.rotation.x = -0.28
	pad.add_child(plate)
	for row in 4:
		for col in 5:
			var key := MeshInstance3D.new()
			var key_mesh := BoxMesh.new()
			key_mesh.size = Vector3(0.036, 0.016, 0.026)
			key.mesh = key_mesh
			var accent := col == 4 and row < 3
			key.material_override = _flat(Color(0.8, 0.45, 0.2) if accent else Color(0.62, 0.62, 0.58), 0.6)
			key.position = Vector3(-0.108 + col * 0.054, 0.024, -0.058 + row * 0.04)
			pad.add_child(key)
	add_child(pad)

func _flat(color: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return m

func _make_player(freq: float, ms: int, pos: Vector3) -> AudioStreamPlayer3D:
	var p := Tone.player(Tone.stream(freq, ms), pos)
	add_child(p)
	return p

func _exit_tree() -> void:
	for p in [_beep, _chime]:
		if p:
			p.stop()
			p.stream = null

func in_zone(pos: Vector3) -> bool:
	return pos.x >= ZONE_MIN.x and pos.x <= ZONE_MAX.x and pos.z >= ZONE_MIN.y and pos.z <= ZONE_MAX.y and absf(pos.y - COUNTER_TOP) < 0.12

func drop_point(slot: int) -> Vector3:
	return DROP_SLOTS[slot % DROP_SLOTS.size()]

func open_sale(who: Node) -> bool:
	if state != State.IDLE:
		return false
	customer = who
	_set_state(State.OPEN)
	sale_opened.emit(who)
	return true

## Called when any product is put down. Only the counter zone matters.
func on_product_placed(product: Product) -> void:
	if state != State.OPEN or product in items:
		return
	if not in_zone(product.global_position):
		return
	items.append(product)
	product.checkout = self
	item_added.emit(product)
	_refresh_screen()

## Gate for the player's placement; empty string means allowed.
func placement_reason(pos: Vector3) -> String:
	if in_zone(pos) and state != State.OPEN:
		return "Nobody is buying anything right now."
	return ""

func can_scan(product: Product) -> bool:
	return state == State.OPEN and product in items and not product.scanned

func scan(product: Product) -> bool:
	if not can_scan(product):
		return false
	product.scanned = true
	_beep.play()
	item_scanned.emit(product)
	_refresh_screen()
	return true

func scanned_count() -> int:
	return items.filter(func(p): return p.scanned).size()

func total_cents() -> int:
	var total := 0
	for p in items:
		if p.scanned:
			total += p.price()
	return total

func can_take_payment() -> bool:
	return payment_blocked_reason() == "" and state == State.OPEN

func payment_blocked_reason() -> String:
	if state == State.PAID:
		return "Sale complete"
	if state == State.IDLE:
		return "No customer at the counter"
	if items.is_empty():
		return "Nothing on the counter yet"
	var left := items.size() - scanned_count()
	if left > 0:
		return "Scan the items first (%d left)" % left
	return ""

func take_payment() -> bool:
	if not can_take_payment():
		return false
	var ids: Array[String] = []
	for p in items:
		ids.append(p.product_id)
	var tx := {"id": "T%04d" % (history.size() + 1), "items": ids, "total": total_cents()}
	history.append(tx)
	_set_state(State.PAID)
	_chime.play()
	_refresh_screen()
	sale_completed.emit(tx)
	return true

## The customer takes their purchase. Returns the products so they can be carried or discarded.
func release_items() -> Array[Product]:
	var out := items.duplicate()
	for p in out:
		p.checkout = null
	items.clear()
	return out

func close_sale() -> void:
	if state == State.IDLE:
		return
	customer = null
	items.clear()
	_set_state(State.IDLE)
	_refresh_screen()
	sale_closed.emit()

func status_text() -> String:
	match state:
		State.IDLE: return "Idle."
		State.OPEN: return "%d of %d items scanned. Total %s." % [scanned_count(), items.size(), ProductCatalog.price_text(total_cents())]
		_: return "Paid %s." % ProductCatalog.price_text(history.back().total)

func _set_state(next: State) -> void:
	state = next
	state_changed.emit(next)

func _refresh_screen() -> void:
	if _lcd == null:
		return
	match state:
		State.IDLE:
			_lcd.text = "TOTAL    $0.00\nCLOSING TIME"
		State.OPEN:
			var line := "SCAN %d/%d" % [scanned_count(), items.size()] if not items.is_empty() else "WAITING..."
			_lcd.text = "TOTAL  %7s\n%s" % [ProductCatalog.price_text(total_cents()), line]
		State.PAID:
			_lcd.text = "TOTAL  %7s\nTHANK YOU" % ProductCatalog.price_text(history.back().total)
