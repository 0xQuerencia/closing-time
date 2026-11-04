class_name PowerGrid
extends Node
## The store's electrics: one main breaker feeding three branch breakers. Everything that needs power asks
## `powered(circuit)` or listens to `changed`; nothing guesses.
signal changed
signal breaker_flipped(id: String, on: bool)
const CIRCUITS := ["lights", "register", "security"]
const EMERGENCY_ENERGY := 0.5
var main_on := true
var branches := {"lights": true, "register": true, "security": true}
var store_lights: Array[Light3D] = []
var _base_energy := {}
var _emissive: Array[StandardMaterial3D] = []
var _emissive_base := {}
var _environment: Environment
var _ambient_base := 0.32
var _emergency: Array[Light3D] = []
var _hum: Array[Node] = []
var _clunk: AudioStreamPlayer
var _buzz: AudioStreamPlayer

func build(world: Node3D) -> PowerGrid:
	name = "PowerGrid"
	for node in world.get_children():
		if node is Light3D and node.is_in_group("store_lights"):
			store_lights.append(node)
			_base_energy[node] = (node as Light3D).light_energy
		elif node is WorldEnvironment:
			_environment = (node as WorldEnvironment).environment
			_ambient_base = _environment.ambient_light_energy
	_hum = world.get_tree().get_nodes_in_group("power_hum")
	_collect_tubes(world)
	_build_emergency(world)
	_clunk = AudioStreamPlayer.new()
	_clunk.stream = Tone.stream(60.0, 380, 1.2, 0.8)
	_clunk.volume_db = -4.0
	add_child(_clunk)
	_buzz = AudioStreamPlayer.new()
	_buzz.stream = Tone.stream(120.0, 240, 1.5, 0.3)
	_buzz.volume_db = -12.0
	add_child(_buzz)
	return self

func _exit_tree() -> void:
	for player in [_clunk, _buzz]:
		if player:
			player.stop()
			player.stream = null

## The fluorescent tubes are an emissive material baked into the shell mesh.
func _collect_tubes(world: Node3D) -> void:
	for mi in world.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		for surface in mesh.get_surface_count():
			var mat := mesh.surface_get_material(surface) as StandardMaterial3D
			if mat != null and mat.emission_enabled and mat.resource_name == "tube":
				var own := mat.duplicate() as StandardMaterial3D
				(mi as MeshInstance3D).set_surface_override_material(surface, own)
				_emissive.append(own)
				_emissive_base[own] = own.emission_energy_multiplier

func _build_emergency(world: Node3D) -> void:
	for pos in [Vector3(4.25, 2.55, -5.35), Vector3(1.7, 2.5, 5.2), Vector3(4.3, 2.5, 2.2)]:
		var lamp := OmniLight3D.new()
		lamp.position = pos
		lamp.light_color = Color(1.0, 0.32, 0.22)
		lamp.light_energy = 0.0
		lamp.omni_range = 3.4
		lamp.shadow_enabled = false
		world.add_child(lamp)
		_emergency.append(lamp)

# --- state --------------------------------------------------------------------------------------

func powered(circuit: String) -> bool:
	return main_on and branches.get(circuit, false)

func all_on() -> bool:
	return main_on and not branches.values().has(false)

## The scripted fault: the main drops and someone has also thrown the security branch.
func trip_all() -> void:
	if not main_on:
		return
	main_on = false
	branches["security"] = false
	_clunk.play()
	_apply()
	changed.emit()
	breaker_flipped.emit("main", false)

func flip(id: String, on: bool) -> bool:
	if id == "main":
		if main_on == on:
			return false
		main_on = on
	elif branches.has(id):
		if branches[id] == on:
			return false
		branches[id] = on
	else:
		return false
	_clunk.play()
	_apply()
	changed.emit()
	breaker_flipped.emit(id, on)
	return true

func reset() -> void:
	main_on = true
	for key in branches:
		branches[key] = true
	_apply()
	changed.emit()

func _apply() -> void:
	var lit := powered("lights")
	for light in store_lights:
		if is_instance_valid(light):
			light.light_energy = _base_energy[light] if lit else 0.0
	for mat in _emissive:
		mat.emission_energy_multiplier = _emissive_base[mat] if lit else 0.0
	if _environment:
		_environment.ambient_light_energy = _ambient_base if lit else 0.045
	for lamp in _emergency:
		lamp.light_energy = 0.0 if lit else EMERGENCY_ENERGY
	for source in _hum:
		if is_instance_valid(source):
			(source as AudioStreamPlayer3D).stream_paused = not main_on
	if lit and _buzz:
		_buzz.play()
