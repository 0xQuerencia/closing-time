class_name GameHud
extends CanvasLayer
## Minimal HUD: crosshair, key-cap prompt, held item, typed dialogue, choices and a closing checklist.
const FONT_REGULAR := preload("res://assets/fonts/jetbrains_mono/JetBrainsMono-Regular.ttf")
const FONT_MEDIUM := preload("res://assets/fonts/jetbrains_mono/JetBrainsMono-Medium.ttf")
const FONT_BOLD := preload("res://assets/fonts/jetbrains_mono/JetBrainsMono-Bold.ttf")
const INK := Color(0.93, 0.9, 0.8)
const DIM := Color(0.93, 0.9, 0.8, 0.5)
const AMBER := Color(0.96, 0.76, 0.36)
const GREEN := Color(0.55, 0.85, 0.6)
const PANEL := Color(0.035, 0.04, 0.045, 0.78)
const SPEAKER_COLORS := {"Jamie": Color(0.55, 0.78, 0.82), "Customer": Color(0.96, 0.76, 0.36)}
var interactor: Interactor
var tasks: TaskManager
var _dot: ColorRect
var _prompt_box: PanelContainer
var _prompt_key: PanelContainer
var _prompt_text: Label
var _prompt_price: Label
var _message: Label
var _held_box: PanelContainer
var _held_name: Label
var _speech_box: PanelContainer
var _speaker: Label
var _line: Label
var _choice_box: VBoxContainer
var _task_box: PanelContainer
var _task_list: VBoxContainer
var _message_left := 0.0
var _line_left := 0.0
var _type_tween: Tween

func setup(inter: Interactor, dialogue: DialogueRunner, task_manager: TaskManager) -> void:
	interactor = inter
	tasks = task_manager
	layer = 10
	_build_crosshair()
	_build_prompt()
	_build_held()
	_build_speech()
	_build_tasks()
	dialogue.line_shown.connect(_on_line)
	dialogue.choices_shown.connect(_on_choices)
	dialogue.finished.connect(func(_id): _clear_choices())
	interactor.message.connect(func(text): _message.text = text; _message_left = 3.5)
	interactor.held_changed.connect(_on_held)
	tasks.task_added.connect(func(_id): _refresh_tasks())
	tasks.objective_completed.connect(func(_t, _o): _refresh_tasks())
	tasks.task_completed.connect(func(_id): _refresh_tasks())
	_refresh_tasks()

func choices_visible() -> bool:
	return _choice_box.get_child_count() > 0

# --- construction -----------------------------------------------------------------------------

func _label(text: String, size: int, color: Color, font: Font = FONT_REGULAR) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	return l

func _style(bg: Color, border: Color, pad_x := 14, pad_y := 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(2)
	s.content_margin_left = pad_x
	s.content_margin_right = pad_x
	s.content_margin_top = pad_y
	s.content_margin_bottom = pad_y
	return s

func _panel(border := Color(0.9, 0.85, 0.65, 0.22), pad_x := 14, pad_y := 8) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", _style(PANEL, border, pad_x, pad_y))
	return p

func _key_cap(key: String, active := true) -> PanelContainer:
	var cap := PanelContainer.new()
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tone := AMBER if active else DIM
	cap.add_theme_stylebox_override("panel", _style(Color(0.1, 0.1, 0.09, 0.9), tone, 7, 1))
	cap.add_child(_label(key, 15, tone, FONT_BOLD))
	return cap

## Pins a box to a screen anchor (0..1) with offsets from it; bottom-anchored boxes grow upward.
func _place(box: Control, anchor_x: float, anchor_y: float, left: float, top: float, width: float) -> void:
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	box.anchor_left = anchor_x
	box.anchor_right = anchor_x
	box.anchor_top = anchor_y
	box.anchor_bottom = anchor_y
	box.offset_left = left
	box.offset_right = left + width
	box.offset_top = top
	box.offset_bottom = top
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN if anchor_y >= 1.0 else Control.GROW_DIRECTION_END
	box.grow_horizontal = Control.GROW_DIRECTION_BEGIN if anchor_x >= 1.0 else Control.GROW_DIRECTION_END

func _build_crosshair() -> void:
	_dot = ColorRect.new()
	# Captured mouse motion lands at viewport center, beneath this decoration.
	_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dot.color = Color(0.93, 0.9, 0.8, 0.6)
	_dot.size = Vector2(4, 4)
	add_child(_dot)
	_dot.set_anchors_preset(Control.PRESET_CENTER)
	_dot.position = Vector2(-2, -2)

func _build_prompt() -> void:
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_BEGIN
	column.add_theme_constant_override("separation", 6)
	_place(column, 0.5, 0.5, -280, 26, 560)
	_prompt_box = _panel()
	_prompt_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	_prompt_key = _key_cap("E")
	row.add_child(_prompt_key)
	_prompt_text = _label("", 17, INK, FONT_MEDIUM)
	row.add_child(_prompt_text)
	_prompt_price = _label("", 17, AMBER, FONT_BOLD)
	row.add_child(_prompt_price)
	_prompt_box.add_child(row)
	column.add_child(_prompt_box)
	_message = _label("", 15, DIM)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_message)
	_prompt_box.visible = false

func _build_held() -> void:
	_held_box = _panel()
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_label("HOLDING", 11, DIM, FONT_BOLD))
	_held_name = _label("", 17, INK, FONT_MEDIUM)
	col.add_child(_held_name)
	var keys := HBoxContainer.new()
	keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	keys.add_theme_constant_override("separation", 6)
	for pair in [["Q", "put down"], ["F", "inspect"]]:
		keys.add_child(_key_cap(pair[0]))
		keys.add_child(_label(pair[1], 13, DIM))
	col.add_child(keys)
	_held_box.add_child(col)
	_place(_held_box, 0.0, 1.0, 24, -24, 0)
	_held_box.visible = false

func _build_speech() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_place(column, 0.5, 1.0, -410, -140, 820)
	_speech_box = _panel(Color(0.9, 0.85, 0.65, 0.18), 20, 12)
	var inner := VBoxContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_theme_constant_override("separation", 4)
	_speaker = _label("", 12, AMBER, FONT_BOLD)
	inner.add_child(_speaker)
	_line = _label("", 21, INK, FONT_MEDIUM)
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(_line)
	_speech_box.add_child(inner)
	column.add_child(_speech_box)
	_choice_box = VBoxContainer.new()
	_choice_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_choice_box.add_theme_constant_override("separation", 6)
	column.add_child(_choice_box)
	_speech_box.visible = false

func _build_tasks() -> void:
	_task_box = _panel(Color(0.9, 0.85, 0.65, 0.18), 16, 12)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.custom_minimum_size = Vector2(300, 0)
	col.add_theme_constant_override("separation", 5)
	col.add_child(_label("CLOSING CHECKLIST", 11, AMBER, FONT_BOLD))
	var rule := ColorRect.new()
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.color = Color(0.9, 0.85, 0.65, 0.2)
	rule.custom_minimum_size = Vector2(0, 1)
	col.add_child(rule)
	_task_list = VBoxContainer.new()
	_task_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_task_list.add_theme_constant_override("separation", 3)
	col.add_child(_task_list)
	_task_box.add_child(col)
	_place(_task_box, 1.0, 0.0, -24 - 332, 24, 332)
	_task_box.visible = false

# --- live updates -----------------------------------------------------------------------------

func _process(delta: float) -> void:
	var info := interactor.current_prompt()
	var shown: bool = info.text != ""
	_prompt_box.visible = shown
	_dot.color = Color(0.96, 0.76, 0.36, 0.9) if shown and info.available else Color(0.93, 0.9, 0.8, 0.6)
	if shown:
		var parts: PackedStringArray = String(info.text).split("  ", false, 1)
		_prompt_text.text = parts[0]
		_prompt_price.text = parts[1] if parts.size() > 1 else ""
		_prompt_key.visible = info.available
		_prompt_box.modulate = Color.WHITE if info.available else Color(1, 1, 1, 0.6)
	if _message_left > 0.0:
		_message_left -= delta
		if _message_left <= 0.0:
			_message.text = ""
	if _line_left > 0.0:
		_line_left -= delta
		if _line_left <= 0.0 and not choices_visible():
			_speech_box.visible = false

func _on_line(speaker: String, text: String) -> void:
	_clear_choices()  # a spoken line means a reply was chosen or the scene moved on
	_speech_box.visible = true
	_speaker.text = speaker.to_upper() if speaker != "" else ""
	_speaker.add_theme_color_override("font_color", SPEAKER_COLORS.get(speaker, AMBER))
	_line.text = text
	_line.visible_ratio = 0.0
	if _type_tween:
		_type_tween.kill()
	_type_tween = create_tween()
	_type_tween.tween_property(_line, "visible_ratio", 1.0, minf(1.2, 0.025 * text.length()))
	_line_left = 1.5 + 0.05 * text.length()

func _on_choices(options: Array) -> void:
	_clear_choices()
	_speech_box.visible = _line_left > 0.0  # choices alone need no speech box
	for i in options.size():
		var backing := _panel(Color(0.9, 0.85, 0.65, 0.22), 12, 5)
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 10)
		row.add_child(_key_cap(str(i + 1)))
		row.add_child(_label(options[i].text, 18, INK, FONT_MEDIUM))
		backing.add_child(row)
		backing.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_choice_box.add_child(backing)

func _clear_choices() -> void:
	for child in _choice_box.get_children():
		_choice_box.remove_child(child)
		child.queue_free()

func _on_held(item: Product) -> void:
	_held_box.visible = item != null
	_held_name.text = "" if item == null else item.display_name

func _refresh_tasks() -> void:
	for child in _task_list.get_children():
		_task_list.remove_child(child)
		child.queue_free()
	var any_active := not tasks.active_ids().is_empty()
	var shown := false
	for id in tasks.tasks:
		var t: Dictionary = tasks.tasks[id]
		if t.done and any_active:
			continue
		shown = true
		_task_list.add_child(_label(("[x] " if t.done else "[ ] ") + t.title, 15, GREEN if t.done else INK, FONT_MEDIUM))
		if not t.done:
			for o in t.objectives:
				_task_list.add_child(_label(("   [x] " if o.done else "   [ ] ") + o.text, 13, GREEN if o.done else DIM))
	_task_box.visible = shown
