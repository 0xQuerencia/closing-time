class_name Flashlight
extends Node
## The phone's torch: T toggles it. Mounted on the player's eyes so it follows where they look.
signal toggled(on: bool)
var light: SpotLight3D
var is_on := false
var _click: AudioStreamPlayer

func build(player: Node3D) -> Flashlight:
	name = "Flashlight"
	light = SpotLight3D.new()
	light.name = "PhoneLight"
	light.spot_range = 9.0
	light.spot_angle = 30.0
	light.spot_angle_attenuation = 0.7
	light.light_energy = 2.6
	light.light_color = Color(0.92, 0.96, 1.0)
	light.shadow_enabled = true
	light.shadow_bias = 0.04
	light.position = Vector3(0.12, -0.1, -0.1)
	light.visible = false
	(player as Node).get("camera").add_child(light)
	_click = AudioStreamPlayer.new()
	_click.stream = Tone.stream(1800.0, 40, 0.8, 0.2)
	_click.volume_db = -14.0
	add_child(_click)
	return self

func _exit_tree() -> void:
	if _click:
		_click.stop()
		_click.stream = null

func set_on(value: bool) -> void:
	if is_on == value:
		return
	is_on = value
	light.visible = value
	_click.play()
	toggled.emit(value)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(GameInput.FLASHLIGHT):
		set_on(not is_on)
