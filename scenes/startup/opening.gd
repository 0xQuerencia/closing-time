extends Control
## Draw the in-engine capture before requesting the playable world.
const WORLD := "res://scenes/world/market_root.tscn"
var _status: Label

func _ready() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color.BLACK
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var art := TextureRect.new()
	art.texture = preload("res://assets/art/market_loading.png")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(art)
	_status = Label.new()
	_status.text = "Loading Marlow's Market…"
	_status.add_theme_font_override("font", preload("res://assets/fonts/pixelify_sans/PixelifySans-Regular.ttf"))
	_status.add_theme_font_size_override("font_size", 24)
	_status.add_theme_constant_override("outline_size", 8)
	_status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_status.position = Vector2(-380, -55)
	_status.size = Vector2(350, 40)
	add_child(_status)
	await RenderingServer.frame_post_draw if DisplayServer.get_name() != "headless" else get_tree().process_frame
	if "--capture-opening" in OS.get_cmdline_user_args():
		DirAccess.make_dir_recursive_absolute("res://local/screenshots/rainy-market")
		get_viewport().get_texture().get_image().save_png("res://local/screenshots/rainy-market/opening.png")
	call_deferred("_open_world")

func _open_world() -> void:
	var scene := load(WORLD) as PackedScene
	if scene == null:
		_status.text = "Could not load the market. Restart to retry."
		push_error("World loading failed")
		return
	var error := get_tree().change_scene_to_packed(scene)
	if error != OK:
		_status.text = "Could not open the market. Restart to retry."
