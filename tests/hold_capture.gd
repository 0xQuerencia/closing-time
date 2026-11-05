class_name HoldCapture
extends Node
## Real-renderer check of what customers carry. Run: godot --path . -- --capture-hold   (local/screenshots/hold/)
const OUT := "res://local/screenshots/hold"
var variants := [["t0", Vector3.ZERO], ["tx+", Vector3(PI / 2, 0, 0)], ["tx-", Vector3(-PI / 2, 0, 0)], ["tz+", Vector3(0, 0, PI / 2)], ["tz-", Vector3(0, 0, -PI / 2)], ["tx180", Vector3(PI, 0, 0)]]

func run(market: Node3D) -> void:
	var game: Gameplay = market.gameplay
	var player: CharacterBody3D = market.player
	DirAccess.make_dir_recursive_absolute(OUT)
	for i in 40:
		await get_tree().process_frame
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hold="):
			only = arg.trim_prefix("--hold=")
	for c in [["mara", "cup_coffee"], ["ben", "cola"], ["leon1", "water"]]:
		if only != "" and only != c[0]:
			continue
		for v in variants:
			var profile: Dictionary = game.profiles.filter(func(pr): return pr.id == c[0])[0]
			var who := Customer.new().setup(game, profile)
			market.add_child(who)
			await get_tree().process_frame
			who.global_position = Vector3(-1.5, 0.0, 2.9)
			who.rotation.y = PI
			var item := game.spawn_product(c[1], null)
			who.held_product = item
			item.attach_to(who._hand, Vector3.ZERO)
			who._play_animation("Idle")
			if who._carry != null:
				who._carry.amount = 1.0
			player.global_position = Vector3(-1.5, 0.0, 4.9)
			player.velocity = Vector3.ZERO
			player.rotation.y = 0.0
			player.camera.rotation.x = -0.12
			for k in 30:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/var_%s_%s.png" % [OUT, c[0], v[0]])
			who.queue_free()
			item.queue_free()
			await get_tree().process_frame
	print("HOLD CAPTURE COMPLETE")
	await market.finish_run(0)
