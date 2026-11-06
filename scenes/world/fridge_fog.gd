class_name FridgeFog
extends Node
## One cooler panel slowly hazes during normal operation and fogs more during a power outage.
var material: ShaderMaterial
var _power: PowerGrid
var _strength := 0.045

func _process(delta: float) -> void:
	if material == null:
		return
	if _power == null:
		_power = get_tree().get_first_node_in_group("power_grid") as PowerGrid
	var target := 0.075
	if _power != null and not _power.main_on:
		target = 0.28
	_strength = move_toward(_strength, target, delta * (0.026 if target > _strength else 0.012))
	material.set_shader_parameter("fog_strength", _strength)
