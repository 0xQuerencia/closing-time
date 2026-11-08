class_name Cctv
extends Node3D
## Three real Godot cameras render into small SubViewports; the office CRT shows the selected one.
## A short low-rate DVR buffer preserves recent frames for review at the desk.
signal entered
signal exited
signal feed_selected(index: int)
signal feed_viewed(index: int)
signal feed_lost(index: int)
const FONT := preload("res://assets/fonts/jetbrains_mono/JetBrainsMono-Bold.ttf")
const FEED_SIZE := Vector2i(320, 240)
const FRAME_SECONDS := 0.1  # ~10 fps, like a cheap recorder
const SCREEN_VIEW_POS := Vector3(7.9, 1.0, -4.62)
const SCREEN_VIEW_TARGET := Vector3(7.9, 0.955, -5.25)
const SEE_MONITOR_RANGE := 6.5
const BOOT_SECONDS := 3.5
const CAMS := [
	{"title": "CAM 1  SHOP FLOOR", "pos": Vector3(-7.9, 2.5, 5.6), "look": Vector3(0.5, 0.9, -0.8), "fov": 82.0},
	{"title": "CAM 2  REAR HALL", "pos": Vector3(4.82, 2.6, 2.3), "look": Vector3(4.25, 0.9, -5.8), "fov": 66.0},
	{"title": "CAM 3  PARKING LOT", "pos": Vector3(3.25, 2.82, 6.4), "look": Vector3(-2.5, 1.0, 12.3), "fov": 42.0}]
var game
var grid: PowerGrid
var sensor: RearSensor
var feeds: Array[Dictionary] = []
var selected := 0
var viewing := false
var viewed := {}
var screen_material: ShaderMaterial
var terminal: SecurityTerminal
var _view_camera: Camera3D
var _ui: CanvasLayer
var _hint: Label
var _frame_clock := 0.0
var _boot_left := 0.0
var _was_live := true
var _glitch_left := 0.0
var _watching := -1
var _next_glitch := 6.0
var _tween: Tween
var _switch_left := 0.0
var _switch_click: AudioStreamPlayer3D
const SWITCH_SECONDS := 0.16
var _proxy: Node3D
var _frame_hold_left := 0.0
var _stamp_jam_left := 0.0
var _threat_was_present: Array[bool] = []
var _rng := RandomNumberGenerator.new()
var _capture_pending: Array[bool] = []
var _record_clock := 0.0
var _record_next := 0
var _history: Array = []
var _opening_tape: Array = []
var _playback_frames: Array = []
var playback := false
var _playback_cursor := -1
const RECORD_INTERVAL := 3.0  # per-feed archive sample, live monitor remains 10 fps
const HISTORY_SECONDS := 300
const OPENING_CLIP_MAX_FRAMES := 18
const OPENING_CLIP_SPAN_MSEC := 18000

func build(owner_game, power: PowerGrid) -> Cctv:
	game = owner_game
	grid = power
	_rng.seed = 4097
	name = "Cctv"
	game.world.add_child(self)
	for index in CAMS.size():
		feeds.append(_build_feed(index))
		_threat_was_present.append(false)
		_capture_pending.append(false)
		_history.append([])
		_opening_tape.append([])
	_build_screen()
	_build_terminal()
	_build_view_camera()
	_build_ui()
	_build_player_proxy()
	power.changed.connect(_on_power_changed)
	return self

# --- feeds --------------------------------------------------------------------------------------

func _build_feed(index: int) -> Dictionary:
	var info: Dictionary = CAMS[index]
	var viewport := SubViewport.new()
	viewport.name = "Feed%d" % (index + 1)
	viewport.size = FEED_SIZE
	viewport.world_3d = get_viewport().world_3d
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.positional_shadow_atlas_size = 0  # recorder feeds reuse lighting without extra shadow passes
	viewport.gui_disable_input = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	var camera := Camera3D.new()
	camera.name = "Lens"
	camera.fov = info.fov
	camera.near = 0.08
	camera.far = 40.0
	camera.cull_mask = 0xFFFFF  # includes the layer-2 proxy of the clerk
	viewport.add_child(camera)
	camera.position = info.pos
	camera.look_at(info.look)
	var title := _feed_label(viewport, info.title, Vector2(8, 6), 14)
	var stamp := _feed_label(viewport, "", Vector2(8, 216), 13)
	var rec := _feed_label(viewport, "REC", Vector2(270, 6), 13)
	var lost := _feed_label(viewport, "NO SIGNAL", Vector2(104, 108), 18)
	lost.visible = false
	var door_log := _feed_label(viewport, "", Vector2(8, 176), 11)
	door_log.visible = index == 1
	return {"viewport": viewport, "camera": camera, "title": title, "stamp": stamp, "rec": rec, "lost": lost, "door": door_log, "dead": false}

func _feed_label(viewport: SubViewport, text: String, pos: Vector2, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.86, 0.95, 0.86))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 4)
	viewport.add_child(label)
	return label

func _build_screen() -> void:
	screen_material = ShaderMaterial.new()
	screen_material.shader = load("res://gameplay/security/cctv_screen.gdshader")
	screen_material.set_shader_parameter("feed", (feeds[0].viewport as SubViewport).get_texture())
	var monitor := game.world.find_child("crt_monitor__static", true, false) as MeshInstance3D
	if monitor == null:
		push_warning("Cctv: office monitor not found, feed will not show on the CRT")
		return
	for surface in monitor.mesh.get_surface_count():
		var mat := monitor.mesh.surface_get_material(surface)
		if mat != null and mat.resource_name == "prop_crt_screen_static":
			monitor.set_surface_override_material(surface, screen_material)

func _build_terminal() -> void:
	terminal = SecurityTerminal.new()
	terminal.cctv = self
	terminal.position = Vector3(7.88, 0.98, -5.2)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.52, 0.45, 0.7)
	shape.shape = box
	terminal.add_child(shape)
	add_child(terminal)
	_switch_click = Tone.player(Tone.stream(2100.0, 22, 0.5, 0.18), Vector3(0, 0.1, 0), 2.0)
	terminal.add_child(_switch_click)

func _build_view_camera() -> void:
	_view_camera = Camera3D.new()
	_view_camera.name = "ScreenView"
	_view_camera.fov = 34.0
	_view_camera.near = 0.05
	add_child(_view_camera)

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 12
	_ui.visible = false
	add_child(_ui)
	_hint = Label.new()
	_hint.text = "A / D  camera     R  review tape     wheel  scrub     E  leave"
	_hint.add_theme_font_override("font", load("res://assets/fonts/pixelify_sans/PixelifySans-Regular.ttf"))
	_hint.add_theme_font_size_override("font_size", 22)
	_hint.add_theme_color_override("font_color", Color(0.9, 0.89, 0.84, 0.8))
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_hint.add_theme_constant_override("outline_size", 6)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.anchor_left = 0.0
	_hint.anchor_right = 1.0
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_top = -64
	_ui.add_child(_hint)

## The clerk has no body in first person, so the cameras see a stand-in on a visibility layer the player's eyes skip.
func _build_player_proxy() -> void:
	var scene := load("res://assets/models/characters/vinrax/casual_male.glb") as PackedScene
	if scene == null:
		return
	_proxy = scene.instantiate() as Node3D
	_proxy.name = "ClerkProxy"
	for mesh in _proxy.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).layers = 2
		(mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var players := _proxy.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty() and (players[0] as AnimationPlayer).has_animation("Idle"):
		var anim := players[0] as AnimationPlayer
		anim.get_animation("Idle").loop_mode = Animation.LOOP_LINEAR
		anim.play("Idle")
	game.world.add_child(_proxy)
	var eyes := game.player.camera as Camera3D
	eyes.cull_mask = eyes.cull_mask & ~2

# --- power, rendering ---------------------------------------------------------------------------

func is_live() -> bool:
	return grid.powered("security") and _boot_left <= 0.0

func is_feed_dead(index: int) -> bool:
	return feeds[index].dead

func _on_power_changed() -> void:
	var live := grid.powered("security")
	if live and not _was_live:
		_boot_left = BOOT_SECONDS
	_was_live = live

func kill_feed(index: int) -> void:
	if feeds[index].dead:
		return
	feeds[index].dead = true
	(feeds[index].lost as Label).visible = true
	feed_lost.emit(index)

func revive_feed(index: int) -> void:
	feeds[index].dead = false
	(feeds[index].lost as Label).visible = false

func _process(delta: float) -> void:
	_boot_left = maxf(0.0, _boot_left - delta)
	_switch_left = maxf(0.0, _switch_left - delta)
	_frame_hold_left = maxf(0.0, _frame_hold_left - delta)
	_stamp_jam_left = maxf(0.0, _stamp_jam_left - delta)
	_next_glitch -= delta
	if _next_glitch <= 0.0:
		_glitch_left = 0.35
		_next_glitch = randf_range(7.0, 16.0)
	_glitch_left = maxf(0.0, _glitch_left - delta)
	var live := grid.powered("security")
	if playback and not live:
		_toggle_playback()  # the recorder lost power, so drop back to the live (dark) screen
	var dead: bool = feeds[selected].dead
	_record_clock -= delta
	if live and _record_clock <= 0.0:
		# Archive each feed every three seconds, render/read back one camera per second.
		# Avoid concentrating three GPU readbacks and JPEG encodes in one frame.
		_record_clock = RECORD_INTERVAL / feeds.size()
		if not feeds[_record_next].dead:
			_record_frame(_record_next)
		_record_next = (_record_next + 1) % feeds.size()
	var leon_seen := _leon_in_feed(selected)
	if leon_seen and not _threat_was_present[selected] and _rng.randf() < 0.55:
		# A cheap DVR briefly repeats a frame as a person crosses the camera's view.
		_frame_hold_left = _rng.randf_range(0.16, 0.32)
		_stamp_jam_left = _rng.randf_range(0.45, 0.9)
		_glitch_left = maxf(_glitch_left, 0.55)
	_threat_was_present[selected] = leon_seen
	screen_material.set_shader_parameter("power", 1.0 if live else 0.0)
	var noise := 0.0
	if _boot_left > 0.0:
		noise = clampf(_boot_left / BOOT_SECONDS, 0.25, 1.0)
	elif playback:
		noise = 0.0
	elif dead:
		noise = 0.5
	if _switch_left > 0.0:  # the DVR rolls a few lines of snow as it changes input
		noise = maxf(noise, _switch_left / SWITCH_SECONDS * 0.85)
	screen_material.set_shader_parameter("static_amount", noise)
	screen_material.set_shader_parameter("playback", 1.0 if playback else 0.0)
	screen_material.set_shader_parameter("glitch", 1.0 if _glitch_left > 0.0 else 0.0)
	screen_material.set_shader_parameter("tracking_amount", 1.0 if leon_seen else 0.0)
	_update_overlay()
	_watch_screen()
	if _proxy != null:
		var player: Node3D = game.player
		_proxy.global_position = player.global_position
		_proxy.rotation.y = player.rotation.y + PI
		_proxy.visible = viewing or live
	_frame_clock -= delta
	if _frame_clock > 0.0 or not live:
		return
	if not _someone_can_see():
		return
	if _frame_hold_left > 0.0:
		return
	_frame_clock = FRAME_SECONDS
	(feeds[selected].viewport as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE

func _leon_in_feed(index: int) -> bool:
	var camera := feeds[index].camera as Camera3D
	for actor in get_tree().get_nodes_in_group("leon_presence"):
		if not is_instance_valid(actor) or not actor is Node3D:
			continue
		var target := (actor as Node3D).global_position + Vector3(0, 1.0, 0)
		if _point_is_in_feed(camera, target):
			return true
	if game != null and game.security != null and is_instance_valid(game.security.intruder):
		var intruder := game.security.intruder as Node3D
		if _point_is_in_feed(camera, intruder.global_position + Vector3(0, 1.0, 0)):
			return true
	return false

func _point_is_in_feed(camera: Camera3D, world_point: Vector3) -> bool:
	if camera.is_position_behind(world_point):
		return false
	var viewport_size := camera.get_viewport().get_visible_rect().size
	var point := camera.unproject_position(world_point)
	return Rect2(Vector2.ZERO, viewport_size).has_point(point)

func _record_frame(index: int) -> void:
	if _capture_pending[index]:
		return  # the previous grab for this camera has not finished drawing yet
	_capture_pending[index] = true
	var viewport := feeds[index].viewport as SubViewport
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_capture_frame_after_render(index)

func _capture_frame_after_render(index: int) -> void:
	await RenderingServer.frame_post_draw
	_capture_pending[index] = false
	if not is_inside_tree() or not grid.powered("security") or feeds[index].dead:
		return
	var image := (feeds[index].viewport as SubViewport).get_texture().get_image()
	if image == null or image.is_empty():
		return
	var jpeg := image.save_jpg_to_buffer(0.58)
	var frame := {"jpeg": jpeg, "time": game.clock.text(), "at_msec": Time.get_ticks_msec()}
	if _opening_witness_in_feed(index):
		var opening: Array = _opening_tape[index]
		if opening.size() < OPENING_CLIP_MAX_FRAMES and (opening.is_empty() or int(frame.at_msec) - int(opening[0].at_msec) <= OPENING_CLIP_SPAN_MSEC):
			opening.append(frame.duplicate())
			_opening_tape[index] = opening
	var frames: Array = _history[index]
	frames.append(frame)
	while frames.size() > ceili(HISTORY_SECONDS / RECORD_INTERVAL):
		frames.pop_front()
	_history[index] = frames

func _opening_witness_in_feed(index: int) -> bool:
	var camera := feeds[index].camera as Camera3D
	for witness in get_tree().get_nodes_in_group("opening_witness"):
		if is_instance_valid(witness) and witness is OpeningWitness and (witness as OpeningWitness).walking_away:
			if _point_is_in_feed(camera, (witness as Node3D).global_position + Vector3(0, 1.0, 0)):
				return true
	return false

func _someone_can_see() -> bool:
	if viewing:
		return true
	var monitor_pos := Vector3(7.9, 1.0, -5.3)
	return game.player.global_position.distance_to(monitor_pos) < SEE_MONITOR_RANGE

func _update_overlay() -> void:
	var minutes: int = (StoryClock.SHIFT_START + int(game.clock.elapsed)) % 1440
	var hours: int = minutes / 60  # integer division is intended
	var text := "11/05  %02d:%02d:%02d" % [hours, minutes % 60, int(Time.get_ticks_msec() / 1000.0) % 60]
	var blink := int(Time.get_ticks_msec() / 600.0) % 2 == 0
	for feed in feeds:
		(feed.stamp as Label).text = text.substr(0, text.length() - 2) + "??" if _stamp_jam_left > 0.0 else text
		(feed.rec as Label).visible = blink and not feed.dead
	if sensor != null:
		(feeds[1].door as Label).text = sensor.last_lines(2)

# --- the desk -----------------------------------------------------------------------------------

func select(index: int) -> void:
	index = clampi(index, 0, feeds.size() - 1)
	if index == selected and viewed.has(index):
		return
	selected = index
	if playback:
		_playback_frames = _tape_frames(index)
		if _playback_frames.is_empty():
			playback = false  # nothing recorded on that camera yet, so show it live
			_playback_cursor = -1
			_set_live_hint()
		else:
			_playback_cursor = _first_sighting_index(index)
			if _playback_cursor < 0:
				_playback_cursor = _playback_frames.size() - 1
	else:
		_playback_cursor = -1
		_set_live_hint()
	_show_selected_feed()
	(feeds[index].viewport as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE
	if viewing:
		_switch_left = SWITCH_SECONDS
		_glitch_left = maxf(_glitch_left, 0.1)
		if _switch_click != null:
			_switch_click.play()
	feed_selected.emit(index)
	_watch_screen()  # Commit the visible feed transition before the next input event.

func _show_selected_feed() -> void:
	if playback and not _playback_frames.is_empty():
		_playback_cursor = clampi(_playback_cursor, 0, _playback_frames.size() - 1)
		var frame: Dictionary = _playback_frames[_playback_cursor]
		if not frame.has("texture"):
			var image := Image.new()
			if image.load_jpg_from_buffer(frame.jpeg) == OK:
				frame.texture = ImageTexture.create_from_image(image)
				_playback_frames[_playback_cursor] = frame
		if frame.has("texture"):
			screen_material.set_shader_parameter("feed", frame.texture)
		screen_material.set_shader_parameter("static_amount", 0.0)
		screen_material.set_shader_parameter("playback", 1.0)
	else:
		screen_material.set_shader_parameter("feed", (feeds[selected].viewport as SubViewport).get_texture())
		screen_material.set_shader_parameter("playback", 0.0)

func _tape_frames(index: int) -> Array:
	var combined: Array = _opening_tape[index].duplicate()
	combined.append_array(_history[index])
	combined.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.at_msec) < int(b.at_msec))
	var unique: Array = []
	var previous_msec := -1
	for frame: Dictionary in combined:
		var stamp := int(frame.at_msec)
		if stamp == previous_msec:
			continue
		unique.append(frame)
		previous_msec = stamp
	return unique

func _first_sighting_index(index: int) -> int:
	var opening: Array = _opening_tape[index]
	if opening.is_empty():
		return -1
	# Skip the first stale frame after the recorder catches the subject walking away.
	var start_frame := mini(1, opening.size() - 1)
	var first_msec := int(opening[start_frame].at_msec)
	for frame_index in _playback_frames.size():
		if int(_playback_frames[frame_index].at_msec) >= first_msec:
			return frame_index
	return -1

func _set_live_hint() -> void:
	_hint.text = "A / D  camera     R  review tape     wheel  scrub     E  leave"
	if not _opening_tape[selected].is_empty():
		_hint.text = "A / D  camera     R  review earlier lot footage     E  leave"

func _toggle_playback() -> void:
	if not playback:
		if not is_live():
			_hint.text = "No signal. The recorder has no power."
			return
		_playback_frames = _tape_frames(selected)
		if _playback_frames.is_empty():
			_hint.text = "No frames saved yet. Check again in a moment."
			return
		playback = true
		_playback_cursor = _first_sighting_index(selected)
		if _playback_cursor >= 0:
			_hint.text = "EARLIER LOT FOOTAGE  %s     wheel  scrub     R  live     E  leave" % _playback_frames[_playback_cursor].time
		else:
			_playback_cursor = _playback_frames.size() - 1
			_hint.text = "RECENT TAPE  %s     wheel  scrub     R  live     E  leave" % _playback_frames[_playback_cursor].time
	else:
		playback = false
		_playback_frames.clear()
		_set_live_hint()
	_show_selected_feed()

func _scrub_tape(step: int) -> void:
	if not playback or _playback_frames.is_empty():
		return
	_playback_cursor = clampi(_playback_cursor + step, 0, _playback_frames.size() - 1)
	_hint.text = "RECORDED  %s     wheel  scrub     R  live     E  leave" % _playback_frames[_playback_cursor].time
	_show_selected_feed()

func cycle(step: int) -> void:
	select(posmod(selected + step, feeds.size()))

## A feed counts as viewed when its powered picture is visible at the seated desk.
func _watch_screen() -> void:
	var watching := -1
	if viewing and not playback and is_live() and not feeds[selected].dead:
		watching = selected
	if watching != _watching and watching >= 0:
		viewed[watching] = true
		feed_viewed.emit(watching)
	_watching = watching

func enter() -> bool:
	if viewing:
		return false
	viewing = true
	_watching = -1
	playback = false
	_playback_frames.clear()
	_set_live_hint()
	game.interactor.enabled = false
	game.interactor.refresh_focus()
	game.player.enabled = false
	game.hud.set_crosshair(false)
	_view_camera.global_transform = (game.player.camera as Camera3D).global_transform
	_view_camera.fov = (game.player.camera as Camera3D).fov
	_view_camera.current = true
	_glide(1.0)
	_ui.visible = true
	entered.emit()
	_watch_screen()
	return true

func leave() -> bool:
	if not viewing:
		return false
	viewing = false
	_watching = -1
	playback = false
	_playback_frames.clear()
	_ui.visible = false
	_glide(0.0)
	return true

func _target_transform() -> Transform3D:
	return Transform3D(Basis.IDENTITY, SCREEN_VIEW_POS).looking_at(SCREEN_VIEW_TARGET, Vector3.UP)

func _glide(to: float) -> void:
	if _tween:
		_tween.kill()
	var eyes := game.player.camera as Camera3D
	_tween = create_tween()
	var end := _target_transform()
	_tween.tween_method(func(t: float):
		_view_camera.global_transform = eyes.global_transform.interpolate_with(end, t)
		_view_camera.fov = lerpf(eyes.fov, 34.0, t), 1.0 - to, to, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.finished.connect(_glide_done.bind(to), CONNECT_ONE_SHOT)

func _glide_done(to: float) -> void:
	_tween = null
	if to == 0.0:
		(game.player.camera as Camera3D).current = true
		game.player.enabled = true
		game.interactor.enabled = true
		game.hud.set_crosshair(true)
		exited.emit()

## Skip the glide (tests): snap straight to the seated or standing state.
func settle() -> void:
	if _tween:
		_tween.kill()
		_tween = null
	if viewing:
		_view_camera.global_transform = _target_transform()
		_view_camera.fov = 34.0
	else:
		_glide_done(0.0)

func _unhandled_input(event: InputEvent) -> void:
	if not viewing:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		if (event as InputEventMouseButton).button_index == MOUSE_BUTTON_WHEEL_UP:
			_scrub_tape(1)
			get_viewport().set_input_as_handled()
		elif (event as InputEventMouseButton).button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scrub_tape(-1)
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).physical_keycode
		if key in [KEY_D, KEY_RIGHT]:
			cycle(1)
		elif key in [KEY_A, KEY_LEFT]:
			cycle(-1)
		elif key in [KEY_E, KEY_ESCAPE, KEY_Q, KEY_S]:
			leave()
		elif key == KEY_R:
			_toggle_playback()
		else:
			return
		get_viewport().set_input_as_handled()

class SecurityTerminal extends Interactable:
	var cctv: Cctv
	func _init() -> void:
		super()
		name = "SecurityTerminal"
		display_name = "security computer"
		verb = "Check the cameras on the"
		description = "The office computer that records the shop, rear hall, and parking lot cameras."
	func can_interact(_actor: Node) -> bool:
		return enabled and not cctv.viewing and cctv.grid.powered("security")
	func blocked_reason(_actor: Node) -> String:
		return "The screen is dark." if not cctv.grid.powered("security") else ""
	func prompt_text(actor: Node) -> String:
		return "Check the cameras" if can_interact(actor) else ""
	func interact(actor: Node) -> void:
		cctv.enter()
		interacted.emit(actor)
