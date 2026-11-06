class_name FlowUI
extends CanvasLayer
## Title screen, pause menu and the ending cards. Plain left-aligned pixel text over a darkened shop, with a yellow
## square on the selected item. Everything here runs while the tree is paused, so the shop holds still behind it.
signal start_requested
signal continue_requested
signal retry_requested
signal restart_requested
signal quit_requested
const FONT := preload("res://assets/fonts/pixelify_sans/PixelifySans-Regular.ttf")
const INK := Color(0.9, 0.89, 0.84)
const DIM := Color(0.9, 0.89, 0.84, 0.6)
const WARM := Color(0.98, 0.84, 0.3)
const TITLE_RED := Color(0.82, 0.13, 0.1)
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
var _shade: ColorRect
var _column: VBoxContainer
var _title: Label
var _body: Label
var _buttons: VBoxContainer
var _footer: Label
var settings := {"retro": true, "sensitivity": 1.0, "bob": false}
var _return_to := "title"
var _guide_return := "game"
const SETTINGS_PATH := "user://settings.cfg"
var persist_settings := false
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
	_shade = ColorRect.new()
	_shade.color = Color(0, 0, 0, 0.85)
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_shade)
	_column = VBoxContainer.new()
	_column.set_anchors_preset(Control.PRESET_CENTER)
	_column.custom_minimum_size = Vector2(680, 0)
	_column.add_theme_constant_override("separation", 14)
	_root.add_child(_column)
	_title = _label(64, INK)
	_column.add_child(_title)
	_body = _label(22, DIM)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_column.add_child(_body)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 6)
	_buttons.alignment = BoxContainer.ALIGNMENT_BEGIN
	_column.add_child(_buttons)
	_footer = _label(16, DIM)
	_footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_column.add_child(_footer)
	apply_settings()
	hide_all()
	return self

## Shipped game only: read and write the player's saved preferences. Tests keep defaults and never touch the file.
func enable_persistence() -> void:
	persist_settings = true
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
	if not persist_settings:
		return
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

func show_guide(return_to := "game") -> void:
	_guide_return = return_to
	_clear_buttons()
	_present("guide", "SHIFT GUIDE", _guide_body(), "G / Esc  close")
	var first := _button("back", "Back", _close_guide)
	first.grab_focus()
	call_deferred("_center_guide")

func _center_guide() -> void:
	await get_tree().process_frame
	if mode == "guide":
		_column.set_anchors_preset(Control.PRESET_TOP_LEFT)
		var viewport_size := get_viewport().get_visible_rect().size
		_column.position = (viewport_size - _column.size) * 0.5

func _guide_body() -> String:
	var current := game.tasks.current_guide()
	var now := "No open task. Take a breath and check your phone when the next message arrives."
	if not current.is_empty():
		now = "NOW\n%s\n%s" % [current.title, current.objective]
		if str(current.hint) != "":
			now += "\n" + str(current.hint)
	return ("Your current objective appears under the clock when it changes, and again if you stall. Press C for the shift list. Each step tells you the room, landmark, and button to use.\n\n" +
		"%s\n\nCONTROLS\nWASD  move     Mouse  look     Shift  run\nE  use / scan / talk     F  inspect     Q  put down\nTab  phone     T  phone light     C  shift list     1 / 2 / 3  reply\nEsc  pause     G  open this guide") % now

func _close_guide() -> void:
	if _guide_return == "title":
		show_title()
	elif _guide_return == "pause":
		show_pause()
	else:
		hide_all()

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
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", 26)
	b.add_theme_color_override("font_color", DIM)
	b.add_theme_color_override("font_hover_color", WARM)
	b.add_theme_color_override("font_focus_color", WARM)
	b.add_theme_color_override("font_pressed_color", WARM)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var marker := ColorRect.new()
	marker.color = WARM
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	marker.offset_left = -24
	marker.offset_right = -14
	marker.offset_top = -5
	marker.offset_bottom = 5
	marker.visible = false
	b.add_child(marker)
	b.focus_entered.connect(func(): marker.visible = true)
	b.focus_exited.connect(func(): marker.visible = false)
	b.mouse_entered.connect(b.grab_focus)
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
	var on_title := next_mode == "title"
	_title.add_theme_font_size_override("font_size", 76 if on_title else 44)
	_title.add_theme_color_override("font_color", TITLE_RED if on_title else INK)
	_body.text = body.replace("\\n", "\n")
	_body.visible = body != ""
	_body.add_theme_font_size_override("font_size", 20 if next_mode == "guide" else (20 if on_title else 22))
	_body.add_theme_color_override("font_color", INK if on_title else DIM)
	_shade.color.a = 0.55 if on_title else 0.86
	_column.anchor_left = 0.1
	_column.anchor_right = 0.1
	_column.anchor_top = 0.5
	_column.anchor_bottom = 0.5
	_column.offset_left = 0
	_column.offset_right = 680
	_column.offset_top = -190
	_column.offset_bottom = -190
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
	_present("title", "CLOSING TIME", "A MARLOW'S MARKET STORY", "WASD move   E use   F look   Q put down   Tab phone   C list   G guide   Esc pause")
	var first := _button("start", "Start shift", func(): _begin(false))
	if SaveGame.exists():
		_button("continue", "Continue", func(): _begin(true))
	_button("guide", "How to play", func(): show_guide("title"))
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
	_button("guide", "Shift guide", func(): show_guide("pause"))
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
	if event.is_action_pressed(GameInput.GUIDE):
		if mode == "guide":
			_close_guide()
		elif mode == "title":
			show_guide("title")
		elif mode == "pause":
			show_guide("pause")
		elif mode == "none" and game.director.step >= StoryDirector.Step.INTRO and game.director.step < StoryDirector.Step.ENDED and not game.security.cctv.viewing:
			show_guide("game")
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if mode == "pause":
			hide_all()
			get_viewport().set_input_as_handled()
		elif mode == "guide":
			_close_guide()
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
