class_name PhoneUI
extends CanvasLayer
## Pocket phone: a toast when a text arrives, Tab to read the threads, never pauses the world.
const FONT := preload("res://assets/fonts/jetbrains_mono/JetBrainsMono-Medium.ttf")
const FONT_BOLD := preload("res://assets/fonts/jetbrains_mono/JetBrainsMono-Bold.ttf")
const INK := Color(0.93, 0.9, 0.8)
const AMBER := Color(0.96, 0.76, 0.36)
const TOAST_SECONDS := 5.0
var model: PhoneModel
var clock: StoryClock
var open := false
var current_thread := "Dina"
var _toast: PanelContainer
var _toast_name: Label
var _toast_text: Label
var _badge: Label
var _panel: PanelContainer
var _header: Label
var _tabs: HBoxContainer
var _log: VBoxContainer
var _toast_left := 0.0
var _buzz: AudioStreamPlayer

func setup(phone: PhoneModel, story_clock: StoryClock) -> void:
	model = phone
	clock = story_clock
	layer = 11
	_build_toast()
	_build_badge()
	_build_panel()
	_buzz = AudioStreamPlayer.new()
	_buzz.stream = Tone.stream(880.0, 160, 0.2, 0.22)
	_buzz.volume_db = -14.0
	add_child(_buzz)
	model.message_received.connect(_on_message)
	model.read_changed.connect(_refresh_badge)
	_refresh_badge()

func _exit_tree() -> void:
	if _buzz:
		_buzz.stop()
		_buzz.stream = null

func _text(text: String, size: int, color: Color, font: Font = FONT) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _panel_style(border := Color(0.9, 0.85, 0.65, 0.25)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.035, 0.04, 0.045, 0.9)
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s

func _pin(box: Control, ax: float, ay: float, left: float, top: float, width: float) -> void:
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	box.anchor_left = ax
	box.anchor_right = ax
	box.anchor_top = ay
	box.anchor_bottom = ay
	box.offset_left = left
	box.offset_right = left + width
	box.offset_top = top
	box.offset_bottom = top
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN if ay >= 1.0 else Control.GROW_DIRECTION_END
	box.grow_horizontal = Control.GROW_DIRECTION_BEGIN if ax >= 1.0 else Control.GROW_DIRECTION_END

func _build_toast() -> void:
	_toast = PanelContainer.new()
	_toast.add_theme_stylebox_override("panel", _panel_style(AMBER * Color(1, 1, 1, 0.6)))
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_name = _text("", 12, AMBER, FONT_BOLD)
	_toast_text = _text("", 16, INK)
	_toast_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_text.custom_minimum_size = Vector2(420, 0)
	col.add_child(_toast_name)
	col.add_child(_toast_text)
	_toast.add_child(col)
	_pin(_toast, 0.5, 0.0, -230, 24, 460)
	_toast.visible = false

func _build_badge() -> void:
	_badge = _text("", 13, AMBER, FONT_BOLD)
	_pin(_badge, 1.0, 1.0, -24 - 200, -24, 200)
	_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _panel_style())
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 8)
	col.custom_minimum_size = Vector2(380, 0)
	_header = _text("", 12, AMBER, FONT_BOLD)
	col.add_child(_header)
	_tabs = HBoxContainer.new()
	_tabs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tabs.add_theme_constant_override("separation", 16)
	col.add_child(_tabs)
	_log = VBoxContainer.new()
	_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log.add_theme_constant_override("separation", 8)
	_log.custom_minimum_size = Vector2(0, 220)
	col.add_child(_log)
	col.add_child(_text("<- ->  switch      Tab  close", 11, Color(0.93, 0.9, 0.8, 0.45)))
	_panel.add_child(col)
	_pin(_panel, 1.0, 1.0, -24 - 412, -56, 412)
	_panel.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(GameInput.PHONE):
		toggle()
	elif open and event.is_action_pressed(GameInput.PHONE_NEXT):
		_switch(1)
	elif open and event.is_action_pressed(GameInput.PHONE_PREV):
		_switch(-1)

func toggle() -> void:
	open = not open
	_panel.visible = open
	if open:
		_toast.visible = false
		model.mark_read(current_thread)
		_render()
	_refresh_badge()

func _switch(step: int) -> void:
	var names: Array = model.threads.keys()
	current_thread = names[(names.find(current_thread) + step + names.size()) % names.size()]
	model.mark_read(current_thread)
	_render()

func _on_message(thread: String, entry: Dictionary) -> void:
	if entry.me:
		if open:
			_render()
		return
	if open and thread == current_thread:
		model.mark_read(thread)
		_render()
	else:
		_toast_name.text = "%s   %s" % [thread.to_upper(), entry.time]
		_toast_text.text = entry.text
		_toast.visible = true
		_toast_left = TOAST_SECONDS
		_buzz.play()
	_refresh_badge()

func _refresh_badge() -> void:
	var unread := model.unread_count()
	_badge.text = "PHONE [Tab]%s" % ("  ●" + str(unread) if unread > 0 else "")
	_badge.visible = true
	if open:
		_render()

func _render() -> void:
	_header.text = "PHONE      %s" % clock.text()
	for child in _tabs.get_children():
		_tabs.remove_child(child)
		child.queue_free()
	for name in model.threads:
		var unread := model.unread_count(name)
		var tab := _text(("[%s]" if name == current_thread else " %s ") % (name + ("*" if unread > 0 else "")), 14, AMBER if name == current_thread else Color(0.93, 0.9, 0.8, 0.5), FONT_BOLD)
		_tabs.add_child(tab)
	for child in _log.get_children():
		_log.remove_child(child)
		child.queue_free()
	var entries: Array = model.threads[current_thread]
	if entries.is_empty():
		_log.add_child(_text("No messages.", 14, Color(0.93, 0.9, 0.8, 0.4)))
	for entry in entries.slice(maxi(0, entries.size() - 5)):
		var bubble := PanelContainer.new()
		bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := _panel_style(Color(0.9, 0.85, 0.65, 0.12))
		style.bg_color = Color(0.12, 0.2, 0.2, 0.9) if entry.me else Color(0.09, 0.09, 0.1, 0.9)
		style.content_margin_top = 6
		style.content_margin_bottom = 6
		bubble.add_theme_stylebox_override("panel", style)
		var inner := VBoxContainer.new()
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var body := _text(entry.text, 15, INK)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size = Vector2(300, 0)
		inner.add_child(body)
		inner.add_child(_text(entry.time, 10, Color(0.93, 0.9, 0.8, 0.4)))
		bubble.add_child(inner)
		bubble.size_flags_horizontal = Control.SIZE_SHRINK_END if entry.me else Control.SIZE_SHRINK_BEGIN
		_log.add_child(bubble)

func _process(delta: float) -> void:
	if _toast_left > 0.0:
		_toast_left -= delta
		if _toast_left <= 0.0:
			_toast.visible = false
