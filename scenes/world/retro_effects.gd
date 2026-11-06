extends CanvasLayer
## Lightweight, independently toggleable finishing pass for the world view.
@export var pixelation_enabled := false
@export var palette_enabled := false
@export var analog_enabled := true

var _material: ShaderMaterial

func _ready() -> void:
	layer = -1
	var finish := ColorRect.new()
	finish.name = "RetroFinish"
	finish.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	finish.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = load("res://scenes/world/retro_effects.gdshader")
	finish.material = _material
	add_child(finish)
	_sync_toggles()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_F6:
			pixelation_enabled = not pixelation_enabled
			_sync_toggles()
			get_viewport().set_input_as_handled()
		KEY_F7:
			palette_enabled = not palette_enabled
			_sync_toggles()
			get_viewport().set_input_as_handled()
		KEY_F8:
			analog_enabled = not analog_enabled
			_sync_toggles()
			get_viewport().set_input_as_handled()

func _sync_toggles() -> void:
	if _material == null:
		return
	_material.set_shader_parameter("pixelation_enabled", pixelation_enabled)
	_material.set_shader_parameter("palette_enabled", palette_enabled)
	_material.set_shader_parameter("analog_enabled", analog_enabled)
