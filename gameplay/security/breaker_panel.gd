class_name BreakerPanel
extends Node3D
## The grey box on the corridor wall: a hinged cover, a main breaker and three branch breakers.
## It reads and writes the PowerGrid; it decides nothing about the story.
signal cover_opened
signal flipped(id: String, on: bool)
const COVER_X := 4.78
const LEVER_X := 4.805
const LEVER_Z := {"main": 2.78, "lights": 2.69, "register": 2.78, "security": 2.87}
const LEVER_Y := {"main": 1.69, "lights": 1.5, "register": 1.5, "security": 1.5}
const TITLES := {"main": "MAIN", "lights": "LIGHTS", "register": "REGISTER", "security": "SECURITY"}
var grid: PowerGrid
var cover: Door
var levers := {}

func build(world: Node3D, power: PowerGrid) -> BreakerPanel:
	name = "BreakerPanel"
	grid = power
	world.add_child(self)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.36, 0.38, 0.37)
	steel.metallic = 0.5
	steel.roughness = 0.55
	steel.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	cover = Door.new().setup(world, "breaker cover", Vector3(COVER_X, 1.27, 2.81), PI / 2.0, Vector3(0.33, 0.5, 0.016), false, steel)
	cover.contact_broken.connect(_on_cover_opened)
	cover.contact_made.connect(_refresh)
	for id in LEVER_Z:
		levers[id] = _build_lever(id)
	power.changed.connect(_refresh)
	_refresh()
	return self

func _on_cover_opened() -> void:
	cover_opened.emit()
	_refresh()

func _build_lever(id: String) -> BreakerLever:
	var lever := BreakerLever.new()
	lever.panel = self
	lever.id = id
	var big := id == "main"
	lever.position = Vector3(LEVER_X, LEVER_Y[id], LEVER_Z[id])
	var grab := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.05, 0.1 if big else 0.085, 0.07 if big else 0.07)
	grab.shape = box
	lever.add_child(grab)
	var handle := MeshInstance3D.new()
	var bar := BoxMesh.new()
	bar.size = Vector3(0.02, 0.075 if big else 0.06, 0.05 if big else 0.032)
	handle.mesh = bar
	handle.name = "Handle"
	lever.add_child(handle)
	var text := Label3D.new()
	text.text = TITLES[id]
	text.font_size = 18
	text.pixel_size = 0.0011
	text.modulate = Color(0.12, 0.12, 0.1)
	text.rotation.y = -PI / 2.0
	text.position = Vector3(-0.001, 0.058 if not big else 0.075, 0)
	text.double_sided = false
	lever.add_child(text)
	add_child(lever)
	return lever

func is_open() -> bool:
	return cover.is_open

func _refresh() -> void:
	var reachable := cover.is_open
	for id in levers:
		var lever: BreakerLever = levers[id]
		var on: bool = grid.main_on if id == "main" else grid.branches[id]
		lever.enabled = reachable
		var handle := lever.get_node("Handle") as MeshInstance3D
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.18, 0.55, 0.28) if on else Color(0.62, 0.16, 0.12)
		mat.roughness = 0.6
		handle.material_override = mat
		handle.position.y = 0.014 if on else -0.014

func flip(id: String) -> void:
	var on: bool = grid.main_on if id == "main" else grid.branches[id]
	if grid.flip(id, not on):
		flipped.emit(id, not on)
	_refresh()

class BreakerLever extends Interactable:
	var panel: BreakerPanel
	var id := ""
	func _init() -> void:
		super()
		verb = "Flip"
	func _on_state() -> bool:
		return panel.grid.main_on if id == "main" else panel.grid.branches[id]
	func can_interact(_actor: Node) -> bool:
		return enabled
	func prompt_text(actor: Node) -> String:
		if not can_interact(actor):
			return ""
		return "%s the %s breaker" % ["Switch off" if _on_state() else "Switch on", BreakerPanel.TITLES[id].to_lower()]
	func interact(actor: Node) -> void:
		panel.flip(id)
		interacted.emit(actor)
	func inspect(actor: Node) -> String:
		inspected.emit(actor)
		var state := "on" if _on_state() else "tripped" if id == "main" else "off"
		var extra := ""
		if id != "main" and not panel.grid.main_on:
			extra = " No power reaches it until the main is on."
		return "%s breaker: %s.%s" % [BreakerPanel.TITLES[id].capitalize(), state, extra]
