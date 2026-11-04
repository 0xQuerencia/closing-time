extends Node3D
## Isolated art/rig comparison. Runtime customers and store are not involved.
const CLIPS := ["Idle", "Walk", "TurnLeft", "TurnRight", "IdleShift", "CounterIdle", "IdleWait"]
var _players: Array[AnimationPlayer] = []
var _viewport: SubViewport
var _camera: Camera3D

func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.12, 0.13, 0.14)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.7, 0.73, 0.78)
	environment.environment.ambient_light_energy = 0.65
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -30, 0)
	light.light_energy = 1.2
	add_child(light)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = PlaneMesh.new()
	floor_mesh.mesh.size = Vector2(12, 12)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.22, 0.23, 0.24)
	floor_mesh.material_override = material
	add_child(floor_mesh)
	var paths := ["res://assets/models/characters/young_man.glb", "res://assets/models/characters/vinrax/casual_male.glb"]
	for index in range(2):
		var model := (load(paths[index]) as PackedScene).instantiate()
		model.position.x = -0.65 if index == 0 else 0.65
		model.rotation.y = PI
		add_child(model)
		preload("res://scenes/world/retro_material_style.gd").apply_nearest_filter(model)
		var animation := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var library := animation.get_animation_library("").duplicate(true) as AnimationLibrary
		animation.remove_animation_library("")
		animation.add_animation_library("", library)
		for clip_name in CLIPS:
			var clip := animation.get_animation(clip_name)
			if not clip_name.begins_with("Turn"):
				clip.loop_mode = Animation.LOOP_LINEAR
			for track in range(clip.get_track_count()):
				clip.track_set_interpolation_type(track, Animation.INTERPOLATION_LINEAR)
		_players.append(animation)
		print("CHARACTER TEST ", paths[index], " clips=", animation.get_animation_list())
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(960, 720)
	_viewport.world_3d = get_viewport().world_3d
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_camera = Camera3D.new()
	_camera.position = Vector3(-2.3, 1.5, -5.3)
	_viewport.add_child(_camera)
	_camera.look_at(Vector3(0, 0.9, 0))
	_camera.current = true
	_camera.fov = 36
	_run()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://local/m32/isolated")
	var sequence := 0
	for clip in CLIPS:
		for animation in _players:
			if not animation.has_animation(clip):
				push_error("Missing retarget clip " + clip)
				get_tree().quit(1)
				return
			animation.play(clip, 0.24)
		for frame in range(75):
			await RenderingServer.frame_post_draw
			var image := _viewport.get_texture().get_image()
			image.save_jpg("res://local/m32/isolated/frame_%05d.jpg" % sequence, 0.9)
			sequence += 1
			if frame in [15, 30, 45, 60]:
				image.save_png("res://local/m32/isolated/%s_%02d.png" % [clip, frame])
	print("ISOLATED CHARACTER TEST COMPLETE")
	if "--capture-test" in OS.get_cmdline_user_args():
		get_tree().quit()
