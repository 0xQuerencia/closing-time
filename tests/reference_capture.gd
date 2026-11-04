class_name ReferenceCapture
extends Node
## Real-renderer stills framed like the art-direction references: local/screenshots/ref_*.png
const VIEWS := [
	["ref_1_counter_customer", Vector3(-3.9, 0.05, 5.15), Vector3(-5.2, 1.3, 2.2)],
	["ref_2_aisle_to_back", Vector3(-1.5, 0.05, 3.2), Vector3(-1.5, 1.4, -3.0)],
	["ref_3_front_window", Vector3(0.9, 0.05, 1.0), Vector3(1.7, 1.5, 6.0)],
	["ref_4_exterior_wide", Vector3(-1.5, 0.0, 15.5), Vector3(1.7, 2.0, 6.0)],
	["ref_5_exterior_right", Vector3(-6.0, 0.0, 14.0), Vector3(6.5, 1.8, 6.5)],
	["ref_6_endcaps", Vector3(-1.5, 0.05, 4.6), Vector3(-3.4, 0.9, 1.8)],
	["ref_7_register", Vector3(-5.8, 0.05, 5.15), Vector3(-5.8, 1.22, 4.4)],
	["ref_8_office_pc", Vector3(7.0, 0.05, -3.3), Vector3(7.6, 0.95, -5.3)],
]

func run(market: Node3D) -> void:
	var player: CharacterBody3D = market.player
	var game: Gameplay = market.gameplay
	DirAccess.make_dir_recursive_absolute("res://local/screenshots")
	var shopper := Customer.new().setup(game, game.profiles[0])
	market.add_child(shopper)
	shopper.global_position = Vector3(-4.6, 0.0, 3.3)
	shopper.rotation.y = 0.0  # faces the counter (-Z is forward, so turn to +Z)
	shopper.rotation.y = PI
	game.hud.visible = false
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
	for view in VIEWS:
		if only != "" and not String(view[0]).contains(only):
			continue
		player.global_position = view[1]
		var d: Vector3 = view[2] - (view[1] + Vector3(0, 1.62, 0))
		player.rotation = Vector3(0, atan2(-d.x, -d.z), 0)
		player.camera.rotation = Vector3(atan2(d.y, Vector2(d.x, d.z).length()), 0, 0)
		for i in 40:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var err := get_viewport().get_texture().get_image().save_png("res://local/screenshots/%s.png" % view[0])
		print("REFERENCE ", view[0], " status=", err)
	await market.finish_run(0)
