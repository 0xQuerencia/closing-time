extends CanvasLayer
## Lightweight, independently toggleable finishing pass for the world view.
@export var pixelation_enabled := false
@export var palette_enabled := false
@export var analog_enabled := true

const TAPE_CHOICE := &"closing_time_subtle_tape"
const POST_ALLOWED := &"closing_time_tape_supported"
var _profile_allows_effect := true
var _material: ShaderMaterial
var _finish: ColorRect

# Scene changes preserve the current profile without adding a global render viewport.
static func install(world: Node) -> CanvasLayer:
	return world.get_node_or_null("WorldTape") if world.has_node("WorldTape") else _add_layer(world)

static func _add_layer(world: Node) -> CanvasLayer:
	var script := load("res://scenes/world/retro_effects.gd") as Script
	var tape: CanvasLayer = script.new()
	tape.name = "WorldTape"
	tape.set_profile(bool(world.get_tree().get_meta(TAPE_CHOICE,true)),
		bool(world.get_tree().get_meta(POST_ALLOWED,not OS.has_feature("web"))))
	world.add_child(tape)
	return tape

func set_profile(subtle: bool, available: bool) -> void:
	analog_enabled = subtle
	_profile_allows_effect = available and not "--safe-mode" in OS.get_cmdline_user_args()
	pixelation_enabled = false
	palette_enabled = false
	_sync_toggles()

func is_drawn() -> bool:
	return is_instance_valid(_finish) and _finish.visible

func _ready() -> void:
	layer = -1
	_finish = ColorRect.new()
	_finish.name = "RetroFinish"
	_finish.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_finish)
	_finish.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_material = ShaderMaterial.new()
	_material.shader = load("res://scenes/world/retro_effects.gdshader")
	_finish.material = _material
	_sync_toggles()

func _unhandled_key_input(event: InputEvent) -> void:
	if not _profile_allows_effect or not event is InputEventKey or not event.pressed or event.echo:
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
			get_tree().set_meta(TAPE_CHOICE,analog_enabled)
			_sync_toggles()
			get_viewport().set_input_as_handled()

func _sync_toggles() -> void:
	if _material == null:
		return
	# Hiding the screen-reading item avoids scheduling the screen copy when off.
	_finish.visible = _profile_allows_effect and (analog_enabled or pixelation_enabled or palette_enabled)
	_material.set_shader_parameter("pixelation_enabled", pixelation_enabled)
	_material.set_shader_parameter("palette_enabled", palette_enabled)
	_material.set_shader_parameter("analog_enabled", analog_enabled)
