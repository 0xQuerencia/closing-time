class_name HidingSpot
extends Interactable
## A gap between the stockroom racks. Crouch in it and Leon only finds you if he walks right up to it, or if he
## watched you go in. Press E or any movement key to come out.
signal hidden_changed(hidden: bool)
const SPOT := Vector3(8.0, 0.0, 3.05)
const STEP_OUT := Vector3(7.0, 0.0, 3.0)
const CROUCH_EYE := 1.0
var game
var occupied := false
var _overlay: CanvasLayer

func build(owner_game) -> HidingSpot:
	game = owner_game
	name = "HidingSpot"
	display_name = "racks"
	verb = "Hide behind the"
	position = Vector3(SPOT.x, 0.9, SPOT.z)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.9, 1.8, 0.9)
	shape.shape = box
	add_child(shape)
	game.world.add_child(self)
	_build_overlay()
	return self

func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 8
	_overlay.visible = false
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0, 0, 0, 0.0))
	gradient.set_color(1, Color(0, 0, 0, 0.92))
	gradient.set_offset(0, 0.35)
	gradient.set_offset(1, 0.95)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 256
	texture.height = 256
	var rect := TextureRect.new()
	rect.texture = texture
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(rect)
	var hint := Label.new()
	hint.text = "Hiding.  E  come out"
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.position.y -= 70
	hint.modulate = Color(0.85, 0.85, 0.8, 0.8)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(hint)
	add_child(_overlay)

func can_interact(_actor: Node) -> bool:
	return enabled and not occupied

func prompt_text(actor: Node) -> String:
	return "Hide behind the racks" if can_interact(actor) else ""

func inspect(actor: Node) -> String:
	inspected.emit(actor)
	return "A narrow gap between two racks. Dark enough."

func interact(actor: Node) -> void:
	enter()
	interacted.emit(actor)

func enter() -> void:
	if occupied:
		return
	var stalker := game.security.intruder as Stalker
	if stalker != null:
		stalker.player_hid()  # did he watch you go in? ask before you vanish
	occupied = true
	var player: CharacterBody3D = game.player
	player.enabled = false
	player.velocity = Vector3.ZERO
	player.global_position = SPOT
	player.camera.position.y = CROUCH_EYE
	_overlay.visible = true
	game.hud.set_crosshair(false)
	hidden_changed.emit(true)

func leave() -> void:
	if not occupied:
		return
	occupied = false
	var player: CharacterBody3D = game.player
	player.global_position = STEP_OUT
	player.camera.position.y = 1.62
	player.enabled = true
	_overlay.visible = false
	game.hud.set_crosshair(true)
	hidden_changed.emit(false)

func _unhandled_input(event: InputEvent) -> void:
	if not occupied or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.physical_keycode in [KEY_E, KEY_W, KEY_A, KEY_S, KEY_D, KEY_SPACE]:
		leave()
		get_viewport().set_input_as_handled()
