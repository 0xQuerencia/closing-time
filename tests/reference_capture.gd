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
	process_mode = Node.PROCESS_MODE_ALWAYS
	var player: CharacterBody3D = market.player
	var game: Gameplay = market.gameplay
	DirAccess.make_dir_recursive_absolute("res://local/screenshots")
	var shopper := Customer.new().setup(game, game.profiles[0])
	market.add_child(shopper)
	shopper.global_position = Vector3(-4.6, 0.0, 3.3)
	shopper.rotation.y = 0.0  # faces the counter (-Z is forward, so turn to +Z)
	shopper.rotation.y = PI
	if "--story" in OS.get_cmdline_user_args():
		await _story_shots(market, game, player)
		await market.finish_run(0)
		return
	var show_hud := "--hud" in OS.get_cmdline_user_args()
	game.hud.visible = show_hud
	if "--guide" in OS.get_cmdline_user_args():
		await _guide_shots(market, game, player)
		await market.finish_run(0)
		return
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

func _guide_shots(market: Node3D, game: Gameplay, player: CharacterBody3D) -> void:
	game.hud.visible = true
	game.phone_ui.visible = true
	game.director.delay_scale = 1.0
	game.director.start()
	player.global_position = Vector3(-6.9, 0.05, 5.2)
	player.rotation = Vector3(0, -0.36, 0)
	player.camera.rotation = Vector3.ZERO
	for i in 40:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://local/guide")
	get_viewport().get_texture().get_image().save_png("res://local/guide/guide_next.png")
	game.flow.show_guide("game")
	for i in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://local/guide/guide_full.png")
	game.flow.hide_all()
	print("GUIDE screenshots saved to res://local/guide")

## HUD close-ups: prompt on a counter item, held item, checklist, choices, then a spoken line.
func _hud_shots(market: Node3D, game: Gameplay, player: CharacterBody3D) -> void:
	game.dialogue.time_scale_for_tests = 1.0
	var item := game.spawn_product("crisps", null)
	game.checkout.open_sale(shopper_stub(market))
	item.place_at(game.checkout.drop_point(0), 0.0)
	game.tasks.add_task("serve_c1", "Serve the customer", [{"id": "at_counter", "text": "Customer at the counter"}, {"id": "scanned", "text": "Scan their items"}, {"id": "paid", "text": "Take payment at the register"}])
	game.tasks.complete_objective("serve_c1", "at_counter")
	var cola := game.spawn_product("cola", Vector3(-7.55, 0.955, 4.4))
	game.interactor.pick_up(cola)
	game.dialogue.start("mara_talk")
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
	print("RECTS viewport=", get_viewport().get_visible_rect().size, " speech=", h._speech.get_global_rect(), " text=", h._speech.text.left(40), " ratio=", h._speech.visible_ratio, " choices=", h._choices.get_global_rect(), " n=", h._choices.get_child_count(), " slip=", h._slip.get_global_rect())
	print("REFERENCE hud done")

func shopper_stub(market: Node3D) -> Node3D:
	var stub := Node3D.new()
	market.add_child(stub)
	return stub

func _story_view(player: CharacterBody3D, from: Vector3, target: Vector3, name: String) -> void:
	player.global_position = from
	var d: Vector3 = target - (from + Vector3(0, 1.62, 0))
	player.rotation = Vector3(0, atan2(-d.x, -d.z), 0)
	player.camera.rotation = Vector3(atan2(d.y, Vector2(d.x, d.z).length()), 0, 0)
	for i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://local/screenshots/story_%s.png" % name)
	print("REFERENCE story_", name)

## Rendered M3 moments: phone, both Leon outfits, chores and the three clues.
func _story_shots(market: Node3D, game: Gameplay, player: CharacterBody3D) -> void:
	game.hud.visible = true
	game.director.spawn_enabled = false
	game.director.delay_scale = 0.0
	game.director.start()
	await get_tree().process_frame
	for id in ["kay_1", "dina_3"]:
		pass
	game.phone.deliver("dina_2", "Dina", "Remember the freezer count. And the back latch sticks. Lift it before you turn the key.", "11:33 PM")
	game.phone.deliver("kay_1", "Kay", "Still doing inventory? Respectfully, why?", "11:44 PM")
	game.phone.deliver("dina_3", "Dina", "Cash drop goes in the office drawer by 11:55. Don't leave it on the desk.", "11:49 PM")
	await _story_view(player, Vector3(-5.6, 0.05, 5.0), Vector3(-5.4, 1.0, 3.6), "1_toast")
	game.phone_ui.toggle()
	await _story_view(player, Vector3(-5.6, 0.05, 5.0), Vector3(-5.4, 1.0, 3.6), "2_phone_open")
	game.phone_ui.toggle()
	for index in [2, 3]:
		var profile: Dictionary = game.profiles[index]
		var leon := Customer.new().setup(game, profile)
		market.add_child(leon)
		leon.global_position = Vector3(-5.0, 0.0, 3.15)
		leon.rotation.y = PI
		await _story_view(player, Vector3(-5.0, 0.05, 5.0), Vector3(-5.0, 1.45, 3.15), "%d_%s" % [index + 1, profile.id])
		leon.queue_free()
		await get_tree().process_frame
	var shift := game.shift
	game.interactor.pick_up(game.spawn_product("crisps", null))
	await _story_view(player, Vector3(-6.33, 0.05, 3.4), shift.slots[0].position + Vector3(0, 0.2, 0), "5_restock_gap")
	game.interactor.release_held().queue_free()
	await _story_view(player, Vector3(-7.7, 0.05, 5.3), ShiftTasks.BIN_POINT + Vector3(0, 0.4, 0), "6_trash_bin")
	shift.make_bag(game.interactor)
	await _story_view(player, Vector3(4.25, 0.05, -4.35), ShiftTasks.BAG_SPOT + Vector3(0, 0.08, 0), "7_trash_pickup_mark")
	shift.place_bag(game.interactor.release_held())
	await _story_view(player, Vector3(4.25, 0.05, -4.35), ShiftTasks.BAG_SPOT + Vector3(0, 0.2, 0), "8_trash_bag_placed")
	await _story_view(player, Vector3(4.25, 0.05, -4.9), ShiftTasks.LATCH_POINT + Vector3(0, -0.06, 0), "9_latch")
	game.clues.activate()
	await _story_view(player, Vector3(6.2, 0.05, -3.1), Vector3(5.25, 1.45, -3.1), "10_key_hooks")
	await _story_view(player, Vector3(7.7, 0.05, -4.2), Clues.ENVELOPE_MOVED + Vector3(0, 0.05, 0), "11_envelope")
	await _story_view(player, Vector3(4.3, 0.05, -1.0), Vector3(4.3, 0.0, -5.0), "12_boot_prints")
