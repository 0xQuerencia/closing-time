class_name GameHud
extends CanvasLayer
## Restrained HUD: plain pixel text, no panels. Only the clock is always on. The objective, the shift list and the
## control hints appear when something changes, then fade. Yellow marks things you can act on.
const FONT := preload("res://assets/fonts/jetbrains_mono/JetBrainsMono-Medium.ttf")
const INK := Color(0.92, 0.91, 0.87)
const DIM := Color(0.92, 0.91, 0.87, 0.55)
const WARM := Color(0.98, 0.84, 0.3)
const OBJECTIVE_SECONDS := 6.5
const LIST_SECONDS := 7.0
const STUCK_SECONDS := 80.0
const HINT_PICKUPS := 3
const HELD_CONFUSED_SECONDS := 25.0
const FADE_SPEED := 2.5
## Pickups with the Q / F hint, counted for the whole run so a retry does not repeat the lesson.
static var hint_pickups := 0
var interactor: Interactor
var dialogue: DialogueRunner
var tasks: TaskManager
var _selected := 0
var _choice_rows: Array[Label] = []
var _choice_marks: Array[ColorRect] = []
var _choice_hint: Label
static var choice_hints := 0
var _dot: ColorRect
var _prompt: Label
var _message: Label
var _held: Label
var _held_hint: Label
var _speech: RichTextLabel
var _choices: VBoxContainer
var _clock: Label
var _objective_box: VBoxContainer
var _objective: Label
var _hint: Label
var _list_box: VBoxContainer
var _message_left := 0.0
var _line_left := 0.0
var _objective_left := 0.0
var _list_left := 0.0
var _idle := 0.0
var _held_time := 0.0
var _show_held_hint := false
var _guide_title := ""
var _guide_key := ""
var _type_tween: Tween

func setup(inter: Interactor, dialogue_runner: DialogueRunner, task_manager: TaskManager) -> void:
	interactor = inter
	dialogue = dialogue_runner
	tasks = task_manager
	layer = 10
	_build_crosshair()
	_prompt = _label(18, INK)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(_prompt, 0.5, 0.5, -360, 34, 720)
	_message = _label(16, DIM)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(_message, 0.5, 0.5, -360, 62, 720)
	_held = _label(18, INK)
	_place(_held, 0.0, 1.0, 28, -58, 560)
	_held_hint = _label(14, DIM)
	_place(_held_hint, 0.0, 1.0, 28, -34, 560)
	_build_speech()
	_build_corner()
	_build_list()
	dialogue_runner.line_shown.connect(_on_line)
	dialogue_runner.choices_shown.connect(_on_choices)
	dialogue_runner.finished.connect(func(_id): _clear_choices())
	interactor.message.connect(func(text): _message.text = text; _message_left = 3.5)
	interactor.held_changed.connect(_on_held)
	tasks.task_added.connect(func(_id): _on_tasks_changed())
	tasks.objective_completed.connect(func(_t, _o): _on_tasks_changed())
	tasks.task_completed.connect(func(_id): _on_tasks_changed())
	tasks.cleared.connect(_on_tasks_changed)
	_on_held(null)
	_refresh_list()
	_refresh_guide()

## The centre dot and prompt only make sense while the player is walking around.
func set_crosshair(shown: bool) -> void:
	_dot.visible = shown
	_prompt.visible = shown

func choices_visible() -> bool:
	return _choices.get_child_count() > 0

func set_clock(text: String) -> void:
	if _clock:
		_clock.text = text

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(GameInput.CHECKLIST):
		show_checklist()
	elif choices_visible() and event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).keycode
		if key == KEY_UP or key == KEY_DOWN:
			_selected = posmod(_selected + (1 if key == KEY_DOWN else -1), _choice_rows.size())
			_mark_selected()
			get_viewport().set_input_as_handled()
		elif key == KEY_ENTER or key == KEY_KP_ENTER:
			dialogue.choose(_selected)
			get_viewport().set_input_as_handled()

## The shift list can also be called up on demand.
func show_checklist() -> void:
	_refresh_list()
	_list_left = LIST_SECONDS
	_objective_left = OBJECTIVE_SECONDS

# --- construction -----------------------------------------------------------------------------

## Plain pixel text with a thin black outline, nearest-filtered so it stays crisp.
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
	_dot.color = Color(0.92, 0.91, 0.87, 0.75)
	_dot.size = Vector2(4, 4)
	_dot.pivot_offset = Vector2(2, 2)
	_dot.rotation = PI / 4.0  # a small diamond
	add_child(_dot)
	_dot.set_anchors_preset(Control.PRESET_CENTER)
	_dot.position = Vector2(-2, -2)

func _build_speech() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_place(column, 0.5, 0.6, -420, 0, 840)
	_speech = RichTextLabel.new()
	_speech.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speech.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_speech.bbcode_enabled = true
	_speech.fit_content = true
	_speech.scroll_active = false
	_speech.custom_minimum_size = Vector2(840, 0)
	_speech.add_theme_font_override("normal_font", FONT)
	_speech.add_theme_font_size_override("normal_font_size", 24)
	_speech.add_theme_color_override("default_color", INK)
	_speech.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_speech.add_theme_constant_override("outline_size", 5)
	column.add_child(_speech)
	_choices = VBoxContainer.new()
	_choices.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_choices.add_theme_constant_override("separation", 4)
	column.add_child(_choices)
	_choice_hint = _label(14, DIM)
	_choice_hint.text = "Up / Down + Enter, or press 1 2 3"
	_choice_hint.visible = false
	column.add_child(_choice_hint)

## Top-left: the clock, and under it the current objective, which appears when it changes or you stall.
func _build_corner() -> void:
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 4)
	_clock = _label(20, INK)
	column.add_child(_clock)
	_place(column, 0.0, 0.0, 28, 18, 300)
	_objective_box = VBoxContainer.new()
	_objective_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_objective_box.add_theme_constant_override("separation", 4)
	_objective_box.modulate.a = 0.0
	_objective = _label(22, WARM)
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective.custom_minimum_size = Vector2(760, 0)
	_objective_box.add_child(_objective)
	_hint = _label(16, DIM)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.custom_minimum_size = Vector2(760, 0)
	_hint.visible = false
	_objective_box.add_child(_hint)
	_place(_objective_box, 0.5, 0.14, -380, 0, 760)

## Top-right: the shift list, plain right-aligned text that is only on screen briefly.
func _build_list() -> void:
	_list_box = VBoxContainer.new()
	_list_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list_box.add_theme_constant_override("separation", 0)
	_list_box.modulate.a = 0.0
	_place(_list_box, 1.0, 0.0, -28 - 440, 84, 440)

# --- live updates -----------------------------------------------------------------------------

func _process(delta: float) -> void:
	var info := interactor.current_prompt()
	if info.text == "":
		_prompt.text = ""
		_dot.color = Color(0.92, 0.91, 0.87, 0.75)
	elif info.available:
		_prompt.text = "[E] " + info.text
		_prompt.modulate = Color.WHITE
		_dot.color = Color(1, 1, 1, 1)
	else:
		_prompt.text = info.text
		_prompt.modulate = Color(1, 1, 1, 0.55)
		_dot.color = Color(0.92, 0.91, 0.87, 0.75)
	if _message_left > 0.0:
		_message_left -= delta
		if _message_left <= 0.0:
			_message.text = ""
	if _line_left > 0.0:
		_line_left -= delta
		if _line_left <= 0.0 and not choices_visible():
			_speech.text = ""
	_tick_objective(delta)
	_tick_held(delta)
	_objective_left = maxf(0.0, _objective_left - delta)
	_list_left = maxf(0.0, _list_left - delta)
	_objective_box.modulate.a = move_toward(_objective_box.modulate.a, 1.0 if _objective_left > 0.0 else 0.0, delta * FADE_SPEED)
	_list_box.modulate.a = move_toward(_list_box.modulate.a, 1.0 if _list_left > 0.0 else 0.0, delta * FADE_SPEED)
	_keep_objective_clear()

## On narrow windows the centred objective would run into the shift list: drop it below the list while both are up.
func _keep_objective_clear() -> void:
	var top := 0.0
	if _list_box.modulate.a > 0.0 and _objective_box.modulate.a > 0.0 and _objective.text != "":
		var width := minf(FONT.get_string_size(_objective.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x, _objective.size.x)
		var view := get_viewport().get_visible_rect().size
		var text_rect := Rect2(view.x * 0.5 - width * 0.5, view.y * 0.14, width, _objective_box.size.y)
		var list_rect := _list_box.get_global_rect().grow(8.0)
		if text_rect.intersects(list_rect):
			top = list_rect.end.y + 10.0 - view.y * 0.14
	_objective_box.offset_top = top
	_objective_box.offset_bottom = top

## A player who has made no progress for a while gets the objective and its hint again.
func _tick_objective(delta: float) -> void:
	if _guide_key == "":
		return
	_idle += delta
	if _idle >= STUCK_SECONDS:
		_idle = 0.0
		_hint.visible = _hint.text != ""
		_objective_left = OBJECTIVE_SECONDS + 3.0

## The Q / F hint is a lesson for the first few pickups, or a reminder when the item has been carried a long time.
func _tick_held(delta: float) -> void:
	if _held.text == "":
		_held_time = 0.0
		return
	_held_time += delta
	var wanted := _show_held_hint or _held_time > HELD_CONFUSED_SECONDS
	_held_hint.modulate.a = move_toward(_held_hint.modulate.a, 1.0 if wanted else 0.0, delta * FADE_SPEED)

func _on_line(speaker: String, text: String) -> void:
	_clear_choices()  # a spoken line means a reply was chosen or the scene moved on
	var named := speaker != "" and not speaker in ["Jamie", "Customer"]
	_speech.text = "%s%s" % [("%s: " % speaker) if named else "", text]
	_speech.visible_ratio = 0.0
	if _type_tween:
		_type_tween.kill()
	_type_tween = create_tween()
	_type_tween.tween_property(_speech, "visible_ratio", 1.0, minf(1.0, 0.02 * text.length()))
	_line_left = 1.5 + 0.05 * text.length()

## Replies are yellow and uppercase, indented under the spoken line, with a square on the selected one.
func _on_choices(options: Array) -> void:
	_clear_choices()
	_selected = 0
	for i in options.size():
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 12)
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(36, 14)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mark := ColorRect.new()
		mark.color = WARM
		mark.size = Vector2(10, 10)
		mark.position = Vector2(22, 6)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(mark)
		row.add_child(slot)
		var text := _label(20, WARM)
		text.text = String(options[i].text).to_upper()
		row.add_child(text)
		_choices.add_child(row)
		_choice_marks.append(mark)
		_choice_rows.append(text)
	_choice_hint.visible = choice_hints < 3
	choice_hints += 1
	_mark_selected()

func _mark_selected() -> void:
	for i in _choice_marks.size():
		_choice_marks[i].visible = i == _selected
		_choice_rows[i].modulate.a = 1.0 if i == _selected else 0.82

func _clear_choices() -> void:
	for child in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()
	_choice_marks.clear()
	_choice_rows.clear()
	if _choice_hint:
		_choice_hint.visible = false

func _on_held(item: Product) -> void:
	_held.text = "" if item == null else item.display_name
	_held_hint.text = "" if item == null else "Q  put down      F  look"
	_held_time = 0.0
	_show_held_hint = false
	if item != null:
		hint_pickups += 1
		_show_held_hint = hint_pickups <= HINT_PICKUPS
	_held_hint.modulate.a = 1.0 if _show_held_hint else 0.0

func _on_tasks_changed() -> void:
	_refresh_list()
	_list_left = LIST_SECONDS
	_refresh_guide()

## One plain line: the task name when a task starts, then the step as it moves on.
func _refresh_guide() -> void:
	if tasks == null:
		return
	var next := tasks.current_guide()
	if next.is_empty():
		_guide_key = ""
		_guide_title = ""
		_objective.text = ""
		_hint.text = ""
		_hint.visible = false
		return
	var key := "%s|%s" % [next.title, next.objective]
	var hint := str(next.hint) if str(next.hint) != "" else "C  shift list"
	if key == _guide_key:
		return
	_objective.text = str(next.objective) if str(next.title) == _guide_title else str(next.title)
	_guide_title = str(next.title)
	_guide_key = key
	_hint.text = hint
	_hint.visible = false
	_idle = 0.0
	_objective_left = OBJECTIVE_SECONDS

## Open tasks, with the steps of only the current one.
func _refresh_list() -> void:
	for child in _list_box.get_children():
		_list_box.remove_child(child)
		child.queue_free()
	var any_active := not tasks.active_ids().is_empty()
	var current := tasks.current_guide()
	for id in tasks.tasks:
		var t: Dictionary = tasks.tasks[id]
		if t.done and any_active:
			continue
		var heading := _label(20, DIM if t.done else INK)
		heading.text = ("x  " if t.done else "") + str(t.title)
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_list_box.add_child(heading)
		if t.done or str(current.get("task_id", "")) != id:
			continue
		for o in t.objectives:
			var step := _label(17, DIM if o.done else WARM)
			step.text = ("x  " if o.done else "-  ") + str(o.text)
			step.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			_list_box.add_child(step)
