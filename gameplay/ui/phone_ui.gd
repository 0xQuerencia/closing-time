class_name PhoneUI
extends CanvasLayer
## Pocket phone. A new text shows as one plain line at the top-right. Tab raises a Nokia-style handset into
## the player's right hand and the thread is read on its real screen. Never pauses the world.
const FONT := preload("res://assets/fonts/jetbrains_mono/JetBrainsMono-Medium.ttf")
const LCD_FONT := preload("res://assets/fonts/pixelify_sans/PixelifySans-Regular.ttf")
const PHONE_MODEL := preload("res://assets/models/props/phone.glb")
const LCD_BG := Color(0.6, 0.73, 0.54)
const LCD_INK := Color(0.08, 0.14, 0.08)
const LCD_DIM := Color(0.08, 0.14, 0.08, 0.6)
const SCREEN_SIZE := Vector2i(164, 150)
const MODEL_HEIGHT := 0.115  # metres, as built
const HOLD_DISTANCE := 0.42
const HOLD_VIEW_FRACTION := 0.57  # how much of the view height the raised handset fills
const RAISE_SPEED := 4.5
const SCROLL_STEP := 22
const TOAST_SECONDS := 4.5
var model: PhoneModel
var clock: StoryClock
var open := false
var current_thread := "Dina"
var _toast: HBoxContainer
var _toast_text: Label
var _badge: Label
var _hint: Label
var _screen_view: SubViewport
var _header: Label
var _log: VBoxContainer
var _scroll: ScrollContainer
var _up_arrow: Control
var _down_arrow: Control
var _rig: Node3D
var _camera: Camera3D
var _held_pose := Transform3D.IDENTITY
var _lowered_pose := Transform3D.IDENTITY
var _raise := 0.0
var _model_scale := 1.0
var _toast_left := 0.0
var _toast_tween: Tween
var _buzz: AudioStreamPlayer
var _arrival_timer: Timer
var _arrival_queue: Array[Dictionary] = []

func setup(phone: PhoneModel, story_clock: StoryClock) -> void:
	model = phone
	clock = story_clock
	layer = 11
	_build_toast()
	_build_badge()
	_build_screen()
	_buzz = AudioStreamPlayer.new()
	_buzz.stream = Tone.stream(880.0, 160, 0.2, 0.22)
	_buzz.volume_db = -14.0
	add_child(_buzz)
	_arrival_timer = Timer.new()
	_arrival_timer.one_shot = true
	_arrival_timer.timeout.connect(_show_queued_message)
	add_child(_arrival_timer)
	model.message_received.connect(_on_message)
	model.read_changed.connect(_refresh_badge)
	visibility_changed.connect(_sync_rig)
	_refresh_badge()

func _exit_tree() -> void:
	if _rig != null:
		var screen := _rig.find_child("PhoneScreen", true, false) as MeshInstance3D
		if screen != null:
			screen.material_override = null  # drop the reference to the viewport texture before it is freed
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

# --- the plain text toast and the unread reminder ---------------------------------------------

## A small speech bubble beside the toast line.
class Bubble extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(24, 20)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var ink := Color(0.92, 0.91, 0.87)
		draw_rect(Rect2(1, 1, 22, 14), ink)
		draw_colored_polygon(PackedVector2Array([Vector2(5, 15), Vector2(5, 20), Vector2(11, 15)]), ink)

func _build_toast() -> void:
	_toast = HBoxContainer.new()
	_toast.add_theme_constant_override("separation", 10)
	_toast.add_child(Bubble.new())
	_toast_text = _text("", 20, Color(0.92, 0.91, 0.87))
	_toast_text.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_toast_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_toast_text.add_theme_constant_override("outline_size", 4)
	_toast_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_text.max_lines_visible = 2
	_toast_text.custom_minimum_size = Vector2(500, 0)
	_toast.add_child(_toast_text)
	_pin(_toast, 1.0, 0.0, -28, 20, 0)  # zero width: the line shrinks to its text and grows leftwards
	_toast.visible = false

func _build_badge() -> void:
	_badge = _outlined("", 18, Color(0.92, 0.91, 0.87, 0.8))
	_pin(_badge, 1.0, 1.0, -28 - 300, -24, 300)
	_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint = _outlined("<  >  switch        Up / Down  scroll        Tab  put away", 16, Color(0.92, 0.91, 0.87, 0.6))
	_pin(_hint, 1.0, 1.0, -28 - 700, -24, 700)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.visible = false

func _outlined(text: String, size: int, color: Color) -> Label:
	var l := _text(text, size, color)
	l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	l.add_theme_constant_override("outline_size", 4)
	return l

# --- the LCD, drawn into a small viewport that the 3D handset's screen displays ----------------

## Signal strength, drawn as four rising bars.
class SignalBars extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(16, 10)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		for i in 4:
			var h := 2.5 + i * 2.5
			draw_rect(Rect2(i * 4.0, 10.0 - h, 3, h), Color(0.08, 0.14, 0.08, 1.0 if i < 3 else 0.28))

## Battery, an outline with segments.
class Battery extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(22, 10)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var ink := Color(0.08, 0.14, 0.08)
		draw_rect(Rect2(0.5, 0.5, 17, 9), ink, false, 1.0)
		draw_rect(Rect2(18, 3, 2, 4), ink)
		for i in 3:
			draw_rect(Rect2(2 + i * 5.0, 2.5, 4, 5), ink)

## A small arrow that says there is more above or below.
class MoreArrow extends Control:
	var up := false
	func _init(points_up: bool) -> void:
		up = points_up
		custom_minimum_size = Vector2(10, 6)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var pts := PackedVector2Array([Vector2(0, 5), Vector2(10, 5), Vector2(5, 0)]) if up else PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(5, 5)])
		draw_colored_polygon(pts, Color(0.08, 0.14, 0.08))

func _box(fill: Color, border: Color, border_px: int, pad_x: int, pad_y: int) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = fill
	st.border_color = border
	st.set_border_width_all(border_px)
	st.content_margin_left = pad_x
	st.content_margin_right = pad_x
	st.content_margin_top = pad_y
	st.content_margin_bottom = pad_y
	return st

func _build_screen() -> void:
	_screen_view = SubViewport.new()
	_screen_view.size = SCREEN_SIZE
	_screen_view.disable_3d = true
	_screen_view.gui_disable_input = true
	_screen_view.transparent_bg = false
	_screen_view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_screen_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_screen_view)
	var face := PanelContainer.new()
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	face.add_theme_stylebox_override("panel", _box(LCD_BG, LCD_BG, 0, 4, 4))
	_screen_view.add_child(face)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 3)
	face.add_child(column)
	var status := HBoxContainer.new()
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.add_child(SignalBars.new())
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.add_child(gap)
	status.add_child(Battery.new())
	column.add_child(status)
	var name_bar := PanelContainer.new()
	name_bar.add_theme_stylebox_override("panel", _box(LCD_BG, LCD_INK, 1, 3, 1))
	_header = _text("", 14, LCD_INK, LCD_FONT)
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_bar.add_child(_header)
	column.add_child(name_bar)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_scroll)
	_log = VBoxContainer.new()
	_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log.add_theme_constant_override("separation", 3)
	_scroll.add_child(_log)
	var arrows := HBoxContainer.new()
	arrows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrows.alignment = BoxContainer.ALIGNMENT_END
	arrows.add_theme_constant_override("separation", 4)
	_up_arrow = MoreArrow.new(true)
	_down_arrow = MoreArrow.new(false)
	arrows.add_child(_up_arrow)
	arrows.add_child(_down_arrow)
	column.add_child(arrows)

# --- the handset in the player's hand ----------------------------------------------------------

## Mount the handset on the player's eyes. It sits below the view until Tab raises it.
func attach_camera(camera: Camera3D) -> void:
	if camera == null or PHONE_MODEL == null:
		return
	_camera = camera
	_rig = PHONE_MODEL.instantiate() as Node3D
	_rig.name = "HeldPhone"
	camera.add_child(_rig)
	_layout_for_view()
	_style_handset()
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.72, 0.92, 0.66)
	glow.light_energy = 0.015
	glow.omni_range = 0.6
	glow.shadow_enabled = false
	glow.position = Vector3(0, 0.01, 0.045)  # just in front of the screen, in model units
	_rig.add_child(glow)
	_apply_pose()
	_sync_rig()

## Size and place the handset from the camera's real view, so it fills the same share of the screen at any
## window shape. The player camera keeps its width, so the height follows from the aspect ratio.
func _layout_for_view() -> void:
	var window := get_viewport().get_visible_rect().size
	var aspect := maxf(0.5, window.x / maxf(1.0, window.y))
	var half_fov := tan(deg_to_rad(_camera.fov) * 0.5)
	var view_w := 2.0 * HOLD_DISTANCE * half_fov
	var view_h := view_w / aspect if _camera.keep_aspect == Camera3D.KEEP_WIDTH else 2.0 * HOLD_DISTANCE * half_fov
	if _camera.keep_aspect != Camera3D.KEEP_WIDTH:
		view_w = view_h * aspect
	_model_scale = HOLD_VIEW_FRACTION * view_h / MODEL_HEIGHT
	var aim := Basis.from_euler(Vector3(-0.2, -0.26, 0.05))
	_held_pose = Transform3D(aim, Vector3(0.2 * view_w, -0.09 * view_h, -HOLD_DISTANCE))
	_lowered_pose = Transform3D(Basis.from_euler(Vector3(-0.55, -0.34, 0.12)), _held_pose.origin + Vector3(0.05 * view_w, -0.9 * view_h, 0.02))

func _style_handset() -> void:
	for node in _rig.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for surface in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.get_active_material(surface) as BaseMaterial3D
			if source == null:
				continue
			var material := source.duplicate() as BaseMaterial3D
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			mesh_instance.set_surface_override_material(surface, material)
	var screen := _rig.find_child("PhoneScreen", true, false) as MeshInstance3D
	if screen != null:
		var lcd := StandardMaterial3D.new()
		lcd.albedo_texture = _screen_view.get_texture()
		lcd.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		lcd.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		screen.material_override = lcd

func _apply_pose() -> void:
	if _rig == null:
		return
	var t := smoothstep(0.0, 1.0, _raise)
	var blended := _lowered_pose.interpolate_with(_held_pose, t)
	_rig.transform = Transform3D(blended.basis.scaled(Vector3.ONE * _model_scale), blended.origin)

func _sync_rig() -> void:
	if _rig == null:
		return
	_rig.visible = visible and _raise > 0.001
	_screen_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if _rig.visible else SubViewport.UPDATE_DISABLED

# --- input and message flow --------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(GameInput.PHONE, false, true):  # exact match: Alt+Tab to another window is not the phone
		toggle()
	elif open and event.is_action_pressed(GameInput.PHONE_NEXT):
		_switch(1)
	elif open and event.is_action_pressed(GameInput.PHONE_PREV):
		_switch(-1)
	elif open and event is InputEventKey and event.pressed and (event.keycode == KEY_UP or event.keycode == KEY_DOWN):
		_scroll_by(-SCROLL_STEP if event.keycode == KEY_UP else SCROLL_STEP)
		get_viewport().set_input_as_handled()
	elif open and event is InputEventMouseButton and event.pressed and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		_scroll_by(-SCROLL_STEP if event.button_index == MOUSE_BUTTON_WHEEL_UP else SCROLL_STEP)

func _scroll_by(pixels: int) -> void:
	_scroll.scroll_vertical = maxi(0, _scroll.scroll_vertical + pixels)
	_update_arrows()

func toggle() -> void:
	open = not open
	_hint.visible = open
	if open:
		if _rig != null:
			_layout_for_view()
		if _toast_tween:
			_toast_tween.kill()
		_toast.visible = false
		_arrival_queue.clear()
		_arrival_timer.stop()
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
		_arrival_queue.append({"thread": thread, "entry": entry.duplicate(true)})
		if _arrival_timer.time_left <= 0.0:
			_arm_message_arrival()
	_refresh_badge()

func _arm_message_arrival() -> void:
	if _arrival_queue.is_empty() or open:
		return
	var entry: Dictionary = _arrival_queue[0].entry
	# A couple of weak-signal texts reach the pocket phone a moment late.
	var delay := 1.35 if entry.get("id", "") in ["kay_2", "dina_5", "dina_7"] else 0.0
	if delay <= 0.0:
		_show_queued_message()  # Timer.start(0) would reuse the previous wait_time
		return
	_arrival_timer.start(delay)

func _show_queued_message() -> void:
	if _arrival_queue.is_empty() or open:
		return
	var arrival: Dictionary = _arrival_queue.pop_front()
	var entry: Dictionary = arrival.entry
	var line := "%s: %s" % [arrival.thread, entry.text]
	_toast_text.text = line
	var wide := _toast_text.get_theme_font("font").get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	_toast_text.custom_minimum_size.x = minf(500.0, wide + 6.0)
	_toast.size = Vector2.ZERO
	if _toast_tween:
		_toast_tween.kill()
	_toast.visible = true
	_toast.modulate.a = 0.0
	_toast_tween = _toast.create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.25)
	_toast_left = TOAST_SECONDS
	_buzz.play()
	_arm_message_arrival()

func _refresh_badge() -> void:
	var unread := model.unread_count()
	_badge.text = "Tab  phone   (%d new)" % unread
	_badge.visible = unread > 0 and not open
	if open:
		_render()

## Fill the LCD: contact name, then the thread as small bordered bubbles, latest at the bottom.
func _render() -> void:
	_header.text = "<  %s  >" % current_thread
	for child in _log.get_children():
		_log.remove_child(child)
		child.queue_free()
	var entries: Array = model.threads[current_thread]
	if entries.is_empty():
		_log.add_child(_text("No messages.", 13, LCD_DIM, LCD_FONT))
	for entry in entries.slice(maxi(0, entries.size() - 12)):
		var bubble := PanelContainer.new()
		bubble.add_theme_stylebox_override("panel", _box(Color(0.08, 0.14, 0.08, 0.12 if entry.me else 0.0), LCD_INK, 1, 3, 2))
		bubble.size_flags_horizontal = Control.SIZE_SHRINK_END if entry.me else Control.SIZE_SHRINK_BEGIN
		var body := _text(entry.text, 13, LCD_INK, LCD_FONT)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size = Vector2(minf(140.0, LCD_FONT.get_string_size(entry.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 2.0), 0)
		bubble.add_child(body)
		_log.add_child(bubble)
	_scroll_to_latest.call_deferred()

func _scroll_to_latest() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)
	_update_arrows()

func _update_arrows() -> void:
	var bar := _scroll.get_v_scroll_bar()
	_up_arrow.modulate.a = 1.0 if _scroll.scroll_vertical > 1 else 0.0
	_down_arrow.modulate.a = 1.0 if _scroll.scroll_vertical < bar.max_value - bar.page - 1.0 else 0.0

func _process(delta: float) -> void:
	var target := 1.0 if open else 0.0
	if not is_equal_approx(_raise, target):
		_raise = move_toward(_raise, target, delta * RAISE_SPEED)
		_apply_pose()
		_sync_rig()
	if _toast_left > 0.0:
		_toast_left -= delta
		if _toast_left <= 0.0:
			if _toast_tween:
				_toast_tween.kill()
			_toast_tween = _toast.create_tween()
			_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.35)
			_toast_tween.tween_callback(func(): _toast.visible = false)
