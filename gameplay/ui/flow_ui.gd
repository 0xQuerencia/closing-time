class_name FlowUI
extends CanvasLayer
## Title screen, pause menu and the ending cards. Plain pixel text on black, like the HUD. Everything here runs
## while the tree is paused, so the shop holds still behind it.
signal start_requested
signal continue_requested
signal retry_requested
signal restart_requested
signal quit_requested
const FONT := preload("res://assets/fonts/pixelify_sans/PixelifySans-Regular.ttf")
const INK := Color(0.9, 0.89, 0.84)
const DIM := Color(0.9, 0.89, 0.84, 0.55)
const ENDINGS := {
	"escape": {
		"title": "OUT",
		"text": "The store alarm is still going when you reach the road.\\nHeadlights turn in from Route 9. Behind you the back door stands open and the office light is on.\\nYour phone buzzes in your pocket. It's Dina. You let it ring."},
	"secured": {
		"title": "HELD",
		"text": "He stops trying the handle when the sirens start. By the time anyone reaches the hall he's gone out the back.\\nThey find the rear door open, a wet bootprint on the step, and the spare key still in the lock.\\nYou sit in the office until it gets light."},
	"caught": {
		"title": "CAUGHT",
		"text": "He gets to you before you get to a door.\\nThe lights hum. Out front, the bell over the entrance rings for nobody.\\nYou should have kept moving."}}
var game: Gameplay
var mode := "none"
var _root: Control
var _title: Label
var _body: Label
var _buttons: VBoxContainer
var _footer: Label
var settings := {"retro": true, "sensitivity": 1.0, "bob": false}
var _return_to := "title"
const SETTINGS_PATH := "user://settings.cfg"
const SENSITIVITIES := [0.6, 1.0, 1.6]

func setup(owner_game: Gameplay) -> FlowUI:
	game = owner_game
	name = "FlowUI"
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.82)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.custom_minimum_size = Vector2(760, 0)
	column.position = Vector2(-380, -190)
	column.add_theme_constant_override("separation", 14)
	_root.add_child(column)
	_title = _label(64, INK)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)
	_body = _label(22, DIM)
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_body)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 6)
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(_buttons)
	_footer = _label(17, DIM)
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_footer)
	_load_settings()
	hide_all()
	return self

func _load_settings() -> void:
	var file := ConfigFile.new()
	if file.load(SETTINGS_PATH) == OK:
		settings.retro = bool(file.get_value("view", "retro", true))
		settings.sensitivity = float(file.get_value("view", "sensitivity", 1.0))
		settings.bob = bool(file.get_value("view", "bob", false))
	apply_settings()

func apply_settings() -> void:
	var player = game.player
	player.sensitivity = settings.sensitivity
	player.head_bob = settings.bob
	for node in game.world.get_children():
		var script: Script = node.get_script()
		if script != null and script.resource_path.ends_with("retro_effects.gd"):
			node.palette_enabled = settings.retro
			node.analog_enabled = settings.retro
			node._sync_toggles()
	var file := ConfigFile.new()
	file.set_value("view", "retro", settings.retro)
	file.set_value("view", "sensitivity", settings.sensitivity)
	file.set_value("view", "bob", settings.bob)
	file.save(SETTINGS_PATH)

func show_settings() -> void:
	_return_to = mode if mode in ["title", "pause"] else _return_to
	_clear_buttons()
	_present("settings", "SETTINGS", "", "Saved automatically")
	var first := _button("retro", "Retro filter: %s" % ("on" if settings.retro else "off"), func():
		settings.retro = not settings.retro
		apply_settings()
		show_settings())
	_button("sensitivity", "Mouse look: %s" % {0.6: "slow", 1.0: "normal", 1.6: "fast"}[settings.sensitivity], func():
		var next := (SENSITIVITIES.find(settings.sensitivity) + 1) % SENSITIVITIES.size()
		settings.sensitivity = SENSITIVITIES[next]
		apply_settings()
		show_settings())
	_button("bob", "Head bob: %s" % ("on" if settings.bob else "off"), func():
		settings.bob = not settings.bob
		apply_settings()
		show_settings())
	_button("back", "Back", func(): show_title() if _return_to == "title" else show_pause())
	first.grab_focus()

func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _button(id: String, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.name = "Btn_" + id
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", 28)
	b.add_theme_color_override("font_color", DIM)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_focus_color", INK)
	b.add_theme_color_override("font_pressed_color", INK)
	b.pressed.connect(action)
	_buttons.add_child(b)
	return b

func _clear_buttons() -> void:
	for child in _buttons.get_children():
		_buttons.remove_child(child)
		child.queue_free()

func _present(next_mode: String, title: String, body: String, footer: String) -> void:
	mode = next_mode
	_title.text = title
	_body.text = body.replace("\\n", "\n")
	_footer.text = footer
	_root.visible = true
	if is_inside_tree():
		get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.hud.visible = false
	game.phone_ui.visible = false

func hide_all() -> void:
	mode = "none"
	_root.visible = false
	if is_inside_tree():
		get_tree().paused = false
	game.hud.visible = true
	game.phone_ui.visible = true
	if not DisplayServer.get_name() == "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func show_title() -> void:
	_clear_buttons()
	_present("title", "CLOSING TIME", "Marlow's Market.  Night shift.  11:24 PM.", "WASD move   Shift run   E use   F look   Q put down   Tab phone   T light   Esc pause")
	var first := _button("start", "Start shift", func(): _begin(false))
	if SaveGame.exists():
		_button("continue", "Continue", func(): _begin(true))
	_button("settings", "Settings", show_settings)
	_button("quit", "Quit", func(): quit_requested.emit())
	first.grab_focus()

func _begin(continuing: bool) -> void:
	hide_all()
	if continuing:
		continue_requested.emit()
	else:
		start_requested.emit()

func show_pause() -> void:
	_clear_buttons()
	_present("pause", "PAUSED", "", "")
	var first := _button("resume", "Resume", hide_all)
	_button("restart", "Restart from the last checkpoint", func(): hide_all(); retry_requested.emit())
	_button("settings", "Settings", show_settings)
	_button("title", "Main menu", func(): restart_requested.emit())
	_button("quit", "Quit", func(): quit_requested.emit())
	first.grab_focus()

func show_ending(kind: String) -> void:
	var entry: Dictionary = ENDINGS[kind]
	_clear_buttons()
	_present("ending_" + kind, entry.title, entry.text, "Closing Time  -  a Hack Club Crescent entry")
	var first: Button
	if kind == "caught":
		first = _button("retry", "Try again", func(): hide_all(); retry_requested.emit())
		_button("title", "Main menu", func(): restart_requested.emit())
	else:
		first = _button("again", "Play again", func(): restart_requested.emit())
	_button("quit", "Quit", func(): quit_requested.emit())
	first.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if mode == "pause":
			hide_all()
			get_viewport().set_input_as_handled()
		elif mode == "settings":
			show_title() if _return_to == "title" else show_pause()
			get_viewport().set_input_as_handled()
		elif mode == "none" and game.director.step >= StoryDirector.Step.INTRO and game.director.step < StoryDirector.Step.ENDED and not game.security.cctv.viewing:
			show_pause()
			get_viewport().set_input_as_handled()

func press(button_id: String) -> bool:
	var b := _buttons.get_node_or_null("Btn_" + button_id) as Button
	if b == null:
		return false
	b.pressed.emit()
	return true

func has_button(button_id: String) -> bool:
	return _buttons.get_node_or_null("Btn_" + button_id) != null
