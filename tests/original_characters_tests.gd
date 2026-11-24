extends SceneTree

func _initialize() -> void:
	call_deferred("_test")

func _test() -> void:
	for character in ["jamie", "leon"]:
		for level in range(3):
			var path := "res://assets/models/characters/original/%s_lod%d.glb" % [character, level]
			var packed := load(path) as PackedScene
			if packed == null:
				printerr("Missing " + path)
				quit(1)
				return
			var model := packed.instantiate()
			root.add_child(model)
			var rigs := model.find_children("*", "Skeleton3D", true, false)
			var players := model.find_children("*", "AnimationPlayer", true, false)
			if rigs.size() != 1 or players.size() != 1 or rigs[0].get_bone_count() != 17 or players[0].get_animation_list().size() < 21:
				printerr("Invalid rig or animation count " + path)
				model.free()
				quit(1)
				return
			for clip in players[0].get_animation_list():
				players[0].play(clip)
				players[0].advance(0.1)
			model.free()
	print("ORIGINAL CHARACTER TESTS COMPLETE")
	quit(0)
