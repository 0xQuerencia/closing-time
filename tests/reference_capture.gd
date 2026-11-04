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
	["ref_9_counter_left", Vector3(-7.4, 0.05, 5.2), Vector3(-7.0, 0.95, 4.1)],
	["ref_10_coffee", Vector3(-6.6, 0.05, -0.6), Vector3(-8.3, 1.1, -0.7)],
	["ref_11_truck", Vector3(-1.0, 0.0, 17.5), Vector3(-4.9, 0.8, 13.0)],
	["ref_12_office_chair", Vector3(7.6, 0.05, -2.8), Vector3(7.6, 0.6, -4.2)],
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
	var show_hud := "--hud" in OS.get_cmdline_user_args()
	game.hud.visible = show_hud
	if show_hud:
		await _hud_shots(market, game, player)
		await market.finish_run(0)
		return
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

## HUD close-ups: prompt on a counter item, held item, checklist, choices, then a spoken line.
func _hud_shots(market: Node3D, game: Gameplay, player: CharacterBody3D) -> void:
	game.dialogue.time_scale_for_tests = 6.0
	var item := game.spawn_product("crisps", null)
	game.checkout.open_sale(shopper_stub(market))
	item.place_at(game.checkout.drop_point(0), 0.0)
	game.tasks.add_task("serve_c1", "Serve the customer", [{"id": "at_counter", "text": "Customer at the counter"}, {"id": "scanned", "text": "Scan their items"}, {"id": "paid", "text": "Take payment at the register"}])
	game.tasks.complete_objective("serve_c1", "at_counter")
	var cola := game.spawn_product("cola", Vector3(-7.55, 0.955, 4.4))
	game.interactor.pick_up(cola)
	game.dialogue.start("c1_talk")
	player.global_position = Vector3(-4.6, 0.05, 5.0)
	var d: Vector3 = item.global_position + Vector3(0, 0.1, 0) - (player.global_position + Vector3(0, 1.62, 0))
	player.rotation = Vector3(0, atan2(-d.x, -d.z), 0)
	player.camera.rotation = Vector3(atan2(d.y, Vector2(d.x, d.z).length()), 0, 0)
	for i in 40:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://local/screenshots/hud_1_choices.png")
	game.dialogue.choose(0)
	for i in 25:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://local/screenshots/hud_2_line.png")
	var h := game.hud
	print("RECTS viewport=", get_viewport().get_visible_rect().size, " task=", h._task_box.get_global_rect(), " vis=", h._task_box.visible, " speech=", h._speech_box.get_global_rect(), " vis=", h._speech_box.visible, " choices=", h._choice_box.get_global_rect(), " n=", h._choice_box.get_child_count(), " prompt=", h._prompt_box.get_global_rect(), " vis=", h._prompt_box.visible)
	print("REFERENCE hud done")

func shopper_stub(market: Node3D) -> Node3D:
	var stub := Node3D.new()
	market.add_child(stub)
	return stub
