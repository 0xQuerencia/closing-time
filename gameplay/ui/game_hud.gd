class_name GameHud
extends CanvasLayer
## Minimal HUD: crosshair, prompt, held item, spoken lines, choices, task list.
var interactor: Interactor
var tasks: TaskManager
var _prompt: Label
var _held: Label
var _message: Label
var _line: Label
var _choices: Label
var _tasks: Label
var _message_left := 0.0
var _line_left := 0.0

func setup(inter: Interactor, dialogue: DialogueRunner, task_manager: TaskManager) -> void:
	interactor = inter
	tasks = task_manager
	layer = 10
	var dot := ColorRect.new()
	# Captured mouse motion lands at viewport center, beneath this decoration.
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.color = Color(0.9, 0.88, 0.8, 0.55)
	dot.size = Vector2(4, 4)
	dot.set_anchors_preset(Control.PRESET_CENTER)
	dot.position = Vector2(-2, -2)
	add_child(dot)
	_prompt = _label(Control.PRESET_CENTER, Vector2(-250, 18), Vector2(500, 28), 17, HORIZONTAL_ALIGNMENT_CENTER)
	_message = _label(Control.PRESET_CENTER, Vector2(-320, 54), Vector2(640, 28), 15, HORIZONTAL_ALIGNMENT_CENTER)
	_held = _label(Control.PRESET_BOTTOM_LEFT, Vector2(24, -44), Vector2(500, 24), 14, HORIZONTAL_ALIGNMENT_LEFT)
	_line = _label(Control.PRESET_CENTER_BOTTOM, Vector2(-380, -150), Vector2(760, 34), 19, HORIZONTAL_ALIGNMENT_CENTER)
	_choices = _label(Control.PRESET_CENTER_BOTTOM, Vector2(-380, -110), Vector2(760, 64), 16, HORIZONTAL_ALIGNMENT_CENTER)
	_tasks = _label(Control.PRESET_TOP_RIGHT, Vector2(-340, 24), Vector2(316, 120), 15, HORIZONTAL_ALIGNMENT_RIGHT)
	dialogue.line_shown.connect(_on_line)
	dialogue.choices_shown.connect(_on_choices)
	dialogue.finished.connect(func(_id): _choices.text = "")
	interactor.message.connect(func(text): _message.text = text; _message_left = 3.5)
	interactor.held_changed.connect(_on_held)
	tasks.task_added.connect(func(_id): _refresh_tasks())
	tasks.objective_completed.connect(func(_t, _o): _refresh_tasks())
	tasks.task_completed.connect(func(_id): _refresh_tasks())
	_refresh_tasks()

func _label(preset: int, offset: Vector2, size: Vector2, font: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.set_anchors_preset(preset)
	l.position = offset
	l.size = size
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", font)
	l.add_theme_color_override("font_color", Color(0.92, 0.89, 0.8))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	add_child(l)
	return l

func _process(delta: float) -> void:
	var info := interactor.current_prompt()
	if info.text == "":
		_prompt.text = ""
	elif info.available:
		_prompt.text = "[E] " + info.text
		_prompt.modulate = Color.WHITE
	else:
		_prompt.text = info.text
		_prompt.modulate = Color(1, 1, 1, 0.55)
	if _message_left > 0.0:
		_message_left -= delta
		if _message_left <= 0.0:
			_message.text = ""
	if _line_left > 0.0:
		_line_left -= delta
		if _line_left <= 0.0:
			_line.text = ""

func _on_line(speaker: String, text: String) -> void:
	_line.text = "%s: %s" % [speaker, text] if speaker != "" else text
	_line_left = 1.5 + 0.05 * text.length()

func _on_choices(options: Array) -> void:
	var rows: Array[String] = []
	for i in options.size():
		rows.append("[%d] %s" % [i + 1, options[i].text])
	_choices.text = "   ".join(rows)

func _on_held(item: Product) -> void:
	_held.text = "" if item == null else "Holding %s    [Q] put down   [F] inspect" % item.display_name

func _refresh_tasks() -> void:
	var rows: Array[String] = []
	for id in tasks.tasks:
		var t: Dictionary = tasks.tasks[id]
		if t.done and tasks.active_ids().size() > 0:
			continue
		rows.append(("✓ " if t.done else "") + t.title)
		if not t.done:
			for o in t.objectives:
				rows.append(("  ✓ " if o.done else "  · ") + o.text)
	_tasks.text = "\n".join(rows)
