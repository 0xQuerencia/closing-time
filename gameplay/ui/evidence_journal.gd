class_name EvidenceJournal
extends CanvasLayer
## Read-only collection of discovered evidence. Never pauses or blocks movement.
var shift: ProductionShift
var panel: PanelContainer
var entries: RichTextLabel

func setup(owner: ProductionShift) -> void:
	shift = owner
	layer = 18
	panel = PanelContainer.new()
	panel.position = Vector2(24,80)
	panel.size = Vector2(430,460)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(.07,.07,.065,.94)
	style.border_color = Color(.45,.43,.36)
	style.set_border_width_all(1)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel",style)
	add_child(panel)
	entries = RichTextLabel.new()
	entries.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entries.bbcode_enabled = false
	entries.add_theme_font_override("normal_font",preload("res://assets/fonts/original/marlow.fnt"))
	entries.add_theme_font_size_override("normal_font_size",20)
	panel.add_child(entries)
	panel.hide()
	shift.progress.event_recorded.connect(func(_id): _refresh())
	shift.director.step_changed.connect(func(step): if step >= StoryDirector.Step.THREAT: panel.hide())
	_refresh()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_J and shift.director.step < StoryDirector.Step.THREAT:
		panel.visible = not panel.visible
		_refresh()
		get_viewport().set_input_as_handled()
	elif panel.visible and event.physical_keycode in [KEY_PAGEUP,KEY_PAGEDOWN]:
		var direction := -1 if event.physical_keycode == KEY_PAGEUP else 1
		entries.scroll_to_line(clampi(entries.get_v_scroll_bar().value / 23 + direction * 8,0,maxi(0,entries.get_line_count()-1)))
		get_viewport().set_input_as_handled()

func _refresh() -> void:
	if entries == null:
		return
	var lines := PackedStringArray(["JAMIE'S NOTES  /  J TO CLOSE","PGUP / PGDN to read",""])
	for id in shift.progress.discoveries:
		var clue: Dictionary = shift.progress.evidence[id]
		lines.append(str(clue.title).to_upper())
		lines.append(str(clue.text))
		lines.append("")
	if shift.progress.discoveries.is_empty():
		lines.append("Nothing noted yet.")
	entries.text = "\n".join(lines)
