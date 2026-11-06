extends SceneTree
const CLIPS := ["Idle", "IdleShift", "IdleWait", "CounterIdle", "LookAround", "Walk", "Run", "Stroll", "TurnLeft", "TurnRight"]
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, detail: String) -> void:
	if not condition:
		failures += 1
		push_error(detail)
	else:
		print("VINRAX TEST PASS: ", detail)

func run() -> void:
	var model := (load("res://assets/models/characters/vinrax/casual_male.glb") as PackedScene).instantiate()
	var source := (load("res://assets/models/characters/young_man.glb") as PackedScene).instantiate()
	root.add_child(model)
	root.add_child(source)
	var skeleton := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var animation := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var original := source.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	check(skeleton.get_bone_count() == 25, "original 25-bone Vinrax skeleton preserved")
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	check(meshes.size() == 1, "one skinned mesh, no Cordatix geometry exported")
	var mesh := meshes[0] as MeshInstance3D
	check(mesh.skin != null and mesh.mesh.get_surface_count() == 1, "one material surface with skin binding")
	check(mesh.mesh.get_faces().size() / 3 == 952, "original downloaded FBX's 952 triangles preserved")
	var material := mesh.get_active_material(0) as BaseMaterial3D
	check(material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST or material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS, "pixelated nearest texture sampling")
	var bounds := mesh.mesh.get_aabb()
	check(bounds.size.y > 1.65 and bounds.size.y < 1.8, "human scale: %.3f m" % bounds.size.y)
	for clip in CLIPS:
		check(animation.has_animation(clip), "required clip " + clip)
		var baked := animation.get_animation(clip)
		check(absf(baked.length - original.get_animation(clip).length) < 0.002, "duration preserved for " + clip)
		animation.play(clip)
		for index in range(21):
			animation.seek(baked.length * index / 20.0, true)
			animation.advance(0.0)
			skeleton.force_update_all_bone_transforms()
			for bone in range(skeleton.get_bone_count()):
				var pose := skeleton.get_bone_global_pose(bone)
				if not pose.is_finite() or pose.origin.length() > 2.5:
					check(false, "invalid bone pose: %s %s" % [clip, skeleton.get_bone_name(bone)])
	print("VINRAX RIG TESTS COMPLETE failures=", failures)
	quit(1 if failures else 0)
