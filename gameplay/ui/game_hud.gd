class_name GameHud
extends CanvasLayer
## Minimal HUD in the spirit of an early-2000s horror game: outlined pixel text, no panels.
## A paper to-do slip stands in for the checklist.
const FONT := preload("res://assets/fonts/pixelify_sans/PixelifySans-Regular.ttf")
const INK := Color(0.9, 0.89, 0.84)
const DIM := Color(0.9, 0.89, 0.84, 0.55)
const PAPER := Color(0.76, 0.72, 0.6)
const PAPER_INK := Color(0.13, 0.11, 0.09)
const PAPER_DONE := Color(0.13, 0.11, 0.09, 0.45)
const SPEAKER_COLORS := {"Jamie": "9fc7c2", "Customer": "d8c9a0"}
var interactor: Interactor
var tasks: TaskManager
var _dot: ColorRect
var _prompt: Label
var _message: Label
var _held: Label
var _held_hint: Label
var _speech: RichTextLabel
var _choices: VBoxContainer
var _slip: PanelContainer
var _slip_list: VBoxContainer
var _clock: Label
var _message_left := 0.0
var _line_left := 0.0
var _type_tween: Tween

func setup(inter: Interactor, dialogue: DialogueRunner, task_manager: TaskManager) -> void:
	interactor = inter
	tasks = task_manager
	layer = 10
	_build_crosshair()
	_prompt = _label(24, INK)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(_prompt, 0.5, 0.5, -400, 30, 800)
	_message = _label(20, DIM)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(_message, 0.5, 0.5, -400, 66, 800)
	_held = _label(22, INK)
	_place(_held, 0.0, 1.0, 28, -62, 500)
	_held_hint = _label(18, DIM)
	_place(_held_hint, 0.0, 1.0, 28, -34, 500)
	_build_speech()
	_build_slip()
	_clock = _label(22, INK)
	_place(_clock, 0.0, 0.0, 28, 22, 200)
	dialogue.line_shown.connect(_on_line)
	dialogue.choices_shown.connect(_on_choices)
	dialogue.finished.connect(func(_id): _clear_choices())
	interactor.message.connect(func(text): _message.text = text; _message_left = 3.5)
	interactor.held_changed.connect(_on_held)
	tasks.task_added.connect(func(_id): _refresh_tasks())
	tasks.objective_completed.connect(func(_t, _o): _refresh_tasks())
	tasks.task_completed.connect(func(_id): _refresh_tasks())
	_on_held(null)
	_refresh_tasks()

func choices_visible() -> bool:
	return _choices.get_child_count() > 0

func set_clock(text: String) -> void:
	if _clock:
		_clock.text = text

# --- construction -----------------------------------------------------------------------------

## Plain pixel text with a hard black outline, nearest-filtered so it stays crisp.
func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	l.add_theme_constant_override("outline_size", 4)
	return l

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
	_dot.color = Color(0.9, 0.89, 0.84, 0.7)
	_dot.size = Vector2(4, 4)
	add_child(_dot)
	_dot.set_anchors_preset(Control.PRESET_CENTER)
	_dot.position = Vector2(-2, -2)

func _build_speech() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_place(column, 0.5, 1.0, -400, -96, 800)
	_speech = RichTextLabel.new()
	_speech.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speech.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_speech.bbcode_enabled = true
	_speech.fit_content = true
	_speech.scroll_active = false
	_speech.custom_minimum_size = Vector2(800, 0)
	_speech.add_theme_font_override("normal_font", FONT)
	_speech.add_theme_font_size_override("normal_font_size", 28)
	_speech.add_theme_color_override("default_color", INK)
	_speech.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_speech.add_theme_constant_override("outline_size", 5)
	column.add_child(_speech)
	_choices = VBoxContainer.new()
	_choices.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_choices.add_theme_constant_override("separation", 2)
	column.add_child(_choices)

func _build_slip() -> void:
	_slip = PanelContainer.new()
	var paper := StyleBoxFlat.new()
	paper.bg_color = PAPER
	paper.shadow_color = Color(0, 0, 0, 0.55)
	paper.shadow_size = 7
	paper.shadow_offset = Vector2(4, 5)
	paper.content_margin_left = 20
	paper.content_margin_right = 20
	paper.content_margin_top = 16
	paper.content_margin_bottom = 18
	_slip.add_theme_stylebox_override("panel", paper)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.custom_minimum_size = Vector2(300, 0)
	col.add_theme_constant_override("separation", 2)
	var title := _paper_label("Closing - to do", 24, PAPER_INK)
	col.add_child(title)
	_slip_list = VBoxContainer.new()
	_slip_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slip_list.add_theme_constant_override("separation", 0)
	col.add_child(_slip_list)
	_slip.add_child(col)
	_place(_slip, 1.0, 0.0, -28 - 344, 26, 344)
	_slip.pivot_offset = Vector2(344, 0)
	_slip.rotation = deg_to_rad(1.6)
	_slip.visible = false

## Ink on the paper slip: no outline, slightly uneven baseline comes from the tilt of the slip.
func _paper_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

# --- live updates -----------------------------------------------------------------------------

func _process(delta: float) -> void:
	var info := interactor.current_prompt()
	if info.text == "":
		_prompt.text = ""
		_dot.color = Color(0.9, 0.89, 0.84, 0.7)
	elif info.available:
		_prompt.text = "E   " + info.text
		_prompt.modulate = Color.WHITE
		_dot.color = Color(1, 1, 1, 1)
	else:
		_prompt.text = info.text
		_prompt.modulate = Color(1, 1, 1, 0.55)
		_dot.color = Color(0.9, 0.89, 0.84, 0.7)
	if _message_left > 0.0:
		_message_left -= delta
		if _message_left <= 0.0:
			_message.text = ""
	if _line_left > 0.0:
		_line_left -= delta
		if _line_left <= 0.0 and not choices_visible():
			_speech.text = ""

func _on_line(speaker: String, text: String) -> void:
	_clear_choices()  # a spoken line means a reply was chosen or the scene moved on
	var tint: String = SPEAKER_COLORS.get(speaker, "d8c9a0")
	_speech.text = ("[center][color=#%s]%s[/color]   %s[/center]" % [tint, speaker.to_upper(), text]) if speaker != "" else "[center]%s[/center]" % text
	_speech.visible_ratio = 0.0
	if _type_tween:
		_type_tween.kill()
	_type_tween = create_tween()
	_type_tween.tween_property(_speech, "visible_ratio", 1.0, minf(1.0, 0.02 * text.length()))
	_line_left = 1.5 + 0.05 * text.length()

func _on_choices(options: Array) -> void:
	_clear_choices()
	for i in options.size():
		var row := _label(26, INK)
		row.text = "%d   %s" % [i + 1, options[i].text]
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_choices.add_child(row)

func _clear_choices() -> void:
	for child in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()

func _on_held(item: Product) -> void:
	_held.text = "" if item == null else item.display_name
	_held_hint.text = "" if item == null else "Q  put down      F  look"

func _refresh_tasks() -> void:
	for child in _slip_list.get_children():
		_slip_list.remove_child(child)
		child.queue_free()
	var any_active := not tasks.active_ids().is_empty()
	var shown := false
	for id in tasks.tasks:
		var t: Dictionary = tasks.tasks[id]
		if t.done and any_active:
			continue
		shown = true
		_slip_list.add_child(_paper_label(("x  " if t.done else "o  ") + t.title, 22, PAPER_DONE if t.done else PAPER_INK))
		if not t.done:
			for o in t.objectives:
				_slip_list.add_child(_paper_label(("      x  " if o.done else "      -  ") + o.text, 18, PAPER_DONE if o.done else PAPER_INK))
	_slip.visible = shown
