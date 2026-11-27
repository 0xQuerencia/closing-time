class_name FlowUI
extends CanvasLayer
## Title screen, pause menu and the ending cards. Plain left-aligned pixel text over a darkened shop, with a yellow
## square on the selected item. Everything here runs while the tree is paused, so the shop holds still behind it.
signal start_requested
signal continue_requested
signal retry_requested
signal restart_requested
signal quit_requested
const FONT_FILE := preload("res://assets/fonts/original/marlow.fnt")
const LOGO_FONT := preload("res://assets/fonts/original/marlow.fnt")
const INK := Color(0.9, 0.89, 0.84)
const DIM := Color(0.9, 0.89, 0.84, 0.6)
const WARM := Color(0.98, 0.84, 0.3)
const ENDINGS := {
	"escaped": {"title":"HOME","text":"I made it to the road. Dina called again, but I could barely hold the phone.\\nI never went back to Marlow's."},
	"rescued": {"title":"WAITING FOR DAYLIGHT","text":"When the officers reached the office, I finally let go of the handle.\\nI kept thinking about Evan."},
	"evidence_preserved": {"title":"THE SECOND COPY","text":"The records and Dina's account were enough to reopen the investigation.\\nThere were no easy answers. But at least someone was asking the right questions."},
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
var _title_fade: TextureRect
var _column: VBoxContainer
var _title: Label
var _body: Label
var _buttons: VBoxContainer
var _footer: Label
const MENU_WIDTH := 680.0
var _menu_scale := 1.0
const GRAPHICS_MODES := ["safe", "performance", "balanced", "quality"]
const GRAPHICS_PRESETS := {
	"safe": {
		"label": "safe",
		"scale": 0.65,
		"msaa": Viewport.MSAA_DISABLED,
		"shadow_atlas": 512,
		"post": false,
		"shadows": false,
		"vertex_lighting": true,
	},
	"performance": {
		"label": "performance",
		"scale": 0.75,
		"msaa": Viewport.MSAA_DISABLED,
		"shadow_atlas": 1024,
		"post": false,
		"shadows": false,
		"vertex_lighting": true,
	},
	"balanced": {
		"label": "balanced",
		"scale": 0.85,
		"msaa": Viewport.MSAA_2X,
		"shadow_atlas": 1536,
		"post": true,
		"shadows": true,
		"vertex_lighting": false,
	},
	"quality": {
		"label": "quality",
		"scale": 1.0,
		"msaa": Viewport.MSAA_2X,
		"shadow_atlas": 2048,
		"post": true,
		"shadows": true,
		"vertex_lighting": false,
	},
}
var settings := {"retro": true, "sensitivity": 1.0, "bob": false, "graphics_mode": "balanced", "render_scale": 0.85, "master_volume": 1.0, "weather_volume": 1.0, "toggle_sprint": false, "reduced_flashes": false}
var _return_to := "title"
var _guide_return := "game"
var _ui_font: FontVariation
const SETTINGS_PATH := "user://settings.cfg"
var persist_settings := false
const SENSITIVITIES := [0.6, 1.0, 1.6]
var _shadow_defaults: Dictionary = {}
var _force_safe_mode := false

func setup(owner_game: Gameplay) -> FlowUI:
	game = owner_game
	_force_safe_mode = "--safe-mode" in OS.get_cmdline_user_args()
	if OS.has_feature("web"):
		settings.graphics_mode = "performance"
	if _force_safe_mode:
		settings.graphics_mode = "safe"
	_ui_font = _make_ui_font(550)
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
	_title_fade = TextureRect.new()
	var fade := Gradient.new()
	fade.colors = PackedColorArray([Color(0, 0, 0, 0.88), Color(0, 0, 0, 0.0)])
	var strip := GradientTexture2D.new()
	strip.gradient = fade
	strip.width = 256
	strip.height = 4
	strip.fill_from = Vector2(0, 0)
	strip.fill_to = Vector2(1, 0)
	_title_fade.texture = strip
	_title_fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_title_fade.stretch_mode = TextureRect.STRETCH_SCALE
	_title_fade.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_title_fade.anchor_right = 0.62
	_title_fade.offset_right = 0
	_title_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_title_fade)
	_column = VBoxContainer.new()
	_root.add_child(_column)
	_title = _label(64, INK)
	_column.add_child(_title)
	_body = _label(18, DIM)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_column.add_child(_body)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 6)
	_buttons.alignment = BoxContainer.ALIGNMENT_BEGIN
	_column.add_child(_buttons)
	_footer = _label(18, DIM)
	_footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_column.add_child(_footer)
	_root.resized.connect(_layout_menu)
	apply_settings()
	hide_all()
	return self

## Shipped game only: read and write the player's saved preferences. Tests keep defaults and never touch the file.
func enable_persistence() -> void:
	persist_settings = true
	var file := ConfigFile.new()
	if not _force_safe_mode and file.load(SETTINGS_PATH) == OK:
		settings.retro = bool(file.get_value("view", "retro", true))
		settings.sensitivity = float(file.get_value("view", "sensitivity", 1.0))
		settings.bob = bool(file.get_value("view", "bob", false))
		for key in ["master_volume","weather_volume"]:
			settings[key] = clampf(float(file.get_value("accessibility",key,1.0)),0.0,1.0)
		for key in ["toggle_sprint","reduced_flashes"]:
			settings[key] = bool(file.get_value("accessibility",key,false))
		var saved_mode := str(file.get_value("view", "graphics_mode", ""))
		if saved_mode in GRAPHICS_MODES:
			settings.graphics_mode = saved_mode
		else:
			# Older builds only saved a scalar. Keep those installs working and
			# map the old value to the closest complete preset.
			var old_scale := clampf(float(file.get_value("view", "render_scale", 0.85)), 0.65, 1.0)
			settings.graphics_mode = _mode_for_scale(old_scale)
	if _force_safe_mode:
		settings.graphics_mode = "safe"
	apply_settings()

func apply_settings() -> void:
	var mode := str(settings.graphics_mode)
	if not GRAPHICS_PRESETS.has(mode):
		mode = "balanced"
		settings.graphics_mode = mode
	var preset: Dictionary = GRAPHICS_PRESETS[mode]
	settings.render_scale = float(preset.scale)
	var viewport := game.get_viewport()
	viewport.scaling_3d_scale = settings.render_scale
	viewport.msaa_3d = int(preset.msaa)
	viewport.positional_shadow_atlas_size = int(preset.shadow_atlas)
	_apply_world_quality(bool(preset.post), bool(preset.shadows))
	game.world.get_node("VisualDirection").set_vertex_lighting(bool(preset.vertex_lighting))
	var player = game.player
	player.sensitivity = settings.sensitivity
	player.head_bob = settings.bob
	player.toggle_sprint = settings.toggle_sprint
	game.director.threat.reduced_flashes = settings.reduced_flashes
	var store_lighting := game.world.get_node("FearsLook") as FearsLook
	store_lighting.reduced_flashes = settings.reduced_flashes
	for pair in [["Master","master_volume"],["Weather","weather_volume"]]:
		var bus := AudioServer.get_bus_index(pair[0])
		if bus >= 0:
			AudioServer.set_bus_volume_db(bus,linear_to_db(maxf(.0001,float(settings[pair[1]]))))
	for node in game.world.get_children():
		var script: Script = node.get_script()
		if script != null and script.resource_path.ends_with("retro_effects.gd"):
			node.palette_enabled = false
			node.analog_enabled = settings.retro
			node._sync_toggles()
	if not persist_settings or _force_safe_mode:
		return
	var file := ConfigFile.new()
	file.set_value("view", "retro", settings.retro)
	file.set_value("view", "sensitivity", settings.sensitivity)
	file.set_value("view", "bob", settings.bob)
	file.set_value("view", "graphics_mode", settings.graphics_mode)
	file.set_value("view", "render_scale", settings.render_scale)
	for key in ["master_volume","weather_volume","toggle_sprint","reduced_flashes"]:
		file.set_value("accessibility",key,settings[key])
	file.save(SETTINGS_PATH)

func show_settings() -> void:
	_return_to = mode if mode in ["title", "pause"] else _return_to
	_clear_buttons()
	_present("settings", "SETTINGS", "", "Saved automatically  /  safe mode is the crash fallback")
	var first := _button("retro", "Retro filter: %s" % ("on" if settings.retro else "off"), func():
		settings.retro = not settings.retro
		apply_settings()
		show_settings())
	_button("sensitivity", "Mouse look: %s" % {0.6: "slow", 1.0: "normal", 1.6: "fast"}[settings.sensitivity], func():
		var next := (SENSITIVITIES.find(settings.sensitivity) + 1) % SENSITIVITIES.size()
		settings.sensitivity = SENSITIVITIES[next]
		apply_settings()
		show_settings())
	_button("graphics_mode", "Graphics mode: %s" % str(GRAPHICS_PRESETS[settings.graphics_mode].label).to_upper(), func():
		var current := GRAPHICS_MODES.find(settings.graphics_mode)
		settings.graphics_mode = GRAPHICS_MODES[(current + 1) % GRAPHICS_MODES.size()]
		apply_settings()
		show_settings())
	_button("bob", "Head bob: %s" % ("on" if settings.bob else "off"), func():
		settings.bob = not settings.bob
		apply_settings()
		show_settings())
	_button("accessibility", "Accessibility / audio", show_accessibility)
	_button("back", "Back", func(): show_title() if _return_to == "title" else show_pause())
	first.grab_focus()

func _mode_for_scale(scale: float) -> String:
	if scale <= 0.68:
		return "safe"
	if scale <= 0.79:
		return "performance"
	if scale < 0.93:
		return "balanced"
	return "quality"

func _apply_world_quality(post_enabled: bool, shadows_enabled: bool) -> void:
	# Cache the authored shadow choices once, so cycling modes never destroys the
	# intended dark composition. Safe/performance can turn them off and restore
	# them when the player returns to balanced/quality.
	for node in game.world.find_children("*", "Light3D", true, false):
		var light := node as Light3D
		var id := light.get_instance_id()
		if not _shadow_defaults.has(id):
			_shadow_defaults[id] = light.shadow_enabled
		light.shadow_enabled = bool(_shadow_defaults[id]) and shadows_enabled
	for node in game.world.find_children("*", "WorldEnvironment", true, false):
		var environment := (node as WorldEnvironment).environment
		if environment == null:
			continue
		environment.ssao_enabled = post_enabled
		environment.glow_enabled = post_enabled

func show_guide(return_to := "game") -> void:
	_guide_return = return_to
	_clear_buttons()
	_present("guide", "SHIFT GUIDE", _guide_body(), "G / Esc  close")
	var first := _button("back", "Back", _close_guide)
	first.grab_focus()

func _center_guide() -> void:
	await get_tree().process_frame
	if mode == "guide":
		_column.position = ((get_viewport().get_visible_rect().size - _column.size) * 0.5).max(Vector2(20, 12))

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
	l.add_theme_font_override("font", _ui_font)
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
	b.add_theme_font_override("font", _ui_font)
	b.add_theme_font_size_override("font_size", _menu_font(26))
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
	_title.add_theme_font_override("font", LOGO_FONT if on_title else _ui_font)
	_title.add_theme_color_override("font_color", INK)
	_body.text = body.replace("\\n", "\n")
	_body.visible = body != ""
	_body.add_theme_color_override("font_color", INK if on_title else DIM)
	_shade.color.a = 0.12 if on_title else 0.86
	_title_fade.visible = on_title
	_footer.text = footer
	_root.visible = true
	_layout_menu()
	if is_inside_tree():
		get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.hud.visible = false
	game.phone_ui.visible = false

func _layout_menu() -> void:
	if mode == "none":
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var left := maxf(28.0, viewport_size.x * 0.1)
	var width := clampf(viewport_size.x - left - 20.0, 1.0, MENU_WIDTH)
	_menu_scale = clampf(minf(width / MENU_WIDTH, viewport_size.y / 600.0), 0.64, 1.0)
	var on_title := mode == "title"
	_title.add_theme_font_size_override("font_size", _menu_font(96 if on_title else 42))
	_body.add_theme_font_size_override("font_size", _menu_font(20 if mode == "guide" else 21))
	_footer.add_theme_font_size_override("font_size", maxi(13, _menu_font(18)))
	_column.add_theme_constant_override("separation", _menu_font(14))
	_buttons.add_theme_constant_override("separation", _menu_font(6))
	for button in _buttons.get_children():
		button.add_theme_font_size_override("font_size", _menu_font(26))
	_column.custom_minimum_size.x = width
	_column.position = Vector2(left, maxf(14.0, viewport_size.y * 0.5 - (330.0 if on_title else 190.0)))
	_column.size = Vector2(width, 0.0)
	if mode == "guide":
		_center_guide.call_deferred()

func _menu_font(size: int) -> int:
	return roundi(float(size) * _menu_scale)

func _make_ui_font(_weight: int) -> FontVariation:
	var variation := FontVariation.new()
	variation.base_font = FONT_FILE
	return variation

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
	var first := _button("start", "New Game", func(): _begin(false))
	if SaveGame.exists() or (game.persist_saves and not OpeningCheckpoint.read().is_empty()):
		_button("continue", "Continue", func(): _begin(true))
	_button("guide", "How to play", func(): show_guide("title"))
	_button("settings", "Settings", show_settings)
	_button("quit", "Quit", func(): quit_requested.emit())
	first.grab_focus()

func _begin(continuing: bool) -> void:
	hide_all()
	if game.persist_saves:
		if not continuing:
			OpeningCheckpoint.erase()
			SaveGame.erase()
			get_tree().set_meta("closing_time_new_game",true)
			get_tree().change_scene_to_file("res://scenes/apartment/apartment.tscn")
			return
		var opening := OpeningCheckpoint.read()
		if not opening.is_empty():
			OpeningCheckpoint.resume(get_tree(),opening)
			return
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
	_present("ending_" + kind, entry.title, entry.text, "Closing Time")
	var first: Button
	if kind == "caught":
		first = _button("retry", "Try again", func(): hide_all(); retry_requested.emit())
		_button("title", "Main menu", func(): restart_requested.emit())
	else:
		if game.director.production != null and kind in ["escaped","rescued","evidence_preserved"]:
			if game.persist_saves:
				OpeningCheckpoint.erase()
				SaveGame.erase()
			first = _button("epilogue", "Two weeks later", func(): _open_epilogue(kind))
			_button("again", "Play again", func(): restart_requested.emit())
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
		elif mode == "accessibility":
			show_settings()
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

func _open_epilogue(kind: String) -> void:
	get_tree().paused = false
	get_tree().set_meta("closing_time_epilogue",kind)
	get_tree().change_scene_to_file("res://scenes/apartment/apartment.tscn")

func show_accessibility() -> void:
	_clear_buttons()
	_present("accessibility","ACCESSIBILITY","","Enter to change  /  Esc back")
	var first := _button("master_volume","Master volume: %d%%" % roundi(settings.master_volume*100),func():
		settings.master_volume = fposmod(settings.master_volume + .25,1.25)
		apply_settings()
		show_accessibility())
	_button("weather_volume","Rain volume: %d%%" % roundi(settings.weather_volume*100),func():
		settings.weather_volume = fposmod(settings.weather_volume + .25,1.25)
		apply_settings()
		show_accessibility())
	_button("toggle_sprint","Sprint: %s" % ("toggle" if settings.toggle_sprint else "hold"),func():
		settings.toggle_sprint = not settings.toggle_sprint
		apply_settings()
		show_accessibility())
	_button("reduced_flashes","Reduced light changes: %s" % ("on" if settings.reduced_flashes else "off"),func():
		settings.reduced_flashes = not settings.reduced_flashes
		apply_settings()
		show_accessibility())
	_button("back","Back",show_settings)
	first.grab_focus()
