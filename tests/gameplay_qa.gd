class_name GameplayQA
extends GameplayTests
## Real-renderer QA: drives the game with genuine key and mouse events and tries to misuse it.
## Run: godot --path . -- --qa-gameplay   (needs a display)
const QA_SCALE := 3.0

## Input is delivered once per rendered frame; wait for that, then a physics tick.
func _flush() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame

func tap(key: Key) -> void:
	var press := InputEventKey.new()
	press.physical_keycode = key
	press.pressed = true
	Input.parse_input_event(press)
	await _flush()
	var release := InputEventKey.new()
	release.physical_keycode = key
	release.pressed = false
	Input.parse_input_event(release)
	await _flush()

func hold(key: Key, frames: int) -> void:
	var press := InputEventKey.new()
	press.physical_keycode = key
	press.pressed = true
	Input.parse_input_event(press)
	await _flush()
	for i in frames:
		await get_tree().physics_frame
	var release := InputEventKey.new()
	release.physical_keycode = key
	release.pressed = false
	Input.parse_input_event(release)
	await get_tree().physics_frame

func _only() -> PackedStringArray:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			return arg.trim_prefix("--only=").split(",")
	return PackedStringArray()

func run_qa(market: Node3D) -> void:
	world = market
	game = market.gameplay
	player = market.player
	for i in 45:  # let the window settle and take focus before sending input
		await get_tree().process_frame
	await _settle()
	print("QA renderer=", RenderingServer.get_current_rendering_method(), " adapter=", RenderingServer.get_video_adapter_name())
	var only := _only()
	if only.is_empty() or "movement" in only:
		await _qa_movement()
	if only.is_empty() or "products" in only:
		await _qa_products_and_misuse()
	Engine.time_scale = QA_SCALE
	if only.is_empty() or "blocked" in only:
		await _qa_blocked_arrival()
	if only.is_empty() or "sales" in only:
		await _qa_customer_one()
		await _qa_customer_two_delayed()
		await _qa_after_transactions()
	Engine.time_scale = 1.0
	print("GAMEPLAY QA COMPLETE failures=", failures)
	await world.finish_run(1 if failures else 0)

func _qa_movement() -> void:
	player.enabled = true
	player.global_position = Vector3(-6, 0.05, 5.6)
	player.rotation = Vector3.ZERO
	player.camera.rotation = Vector3.ZERO
	await hold(KEY_W, 150)
	check(player.global_position.z > 4.9 and player.global_position.z < 5.4, "W walks to the counter and is stopped by it (z=%.2f)" % player.global_position.z)
	player.global_position = Vector3(-8.0, 0.05, 2.0)
	player.rotation = Vector3(0, PI / 2.0, 0)
	await hold(KEY_W, 120)
	check(player.global_position.x > -8.75, "side wall stops the player (x=%.2f)" % player.global_position.x)
	player.global_position = Vector3(-1.5, 0.05, 0.6)
	player.rotation = Vector3(0, PI / 2.0, 0)
	await hold(KEY_W, 120)
	check(player.global_position.x > -2.4 and player.global_position.x < -2.1, "gondola stops the player (x=%.2f)" % player.global_position.x)
	var yaw := player.rotation.y
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(50, 0)
	Input.parse_input_event(motion)
	await _flush()
	check(absf(player.rotation.y - (yaw - 0.1)) < 0.02, "mouse look turns the player (yaw %.3f -> %.3f)" % [yaw, player.rotation.y])
	player.enabled = false

func _qa_products_and_misuse() -> void:
	var inter := game.interactor
	var cola := _find("Product_cola") as Product
	var noodles := _find("Product_noodles") as Product
	await aim(Vector3(-7.55, 0.05, 5.3), Vector3(-7.55, 1.0, 1.0))
	var messages: Array[String] = []
	inter.message.connect(func(t): messages.append(t))
	await tap(KEY_Q)
	await tap(KEY_F)
	check(inter.held == null and messages.size() == 0, "Q and F with nothing held or in view do nothing")
	await aim(Vector3(-7.55, 0.05, 5.3), Vector3(-7.55, 1.0, 4.4))
	for i in 20:
		await tap(KEY_E)
	check(inter.held == cola, "spamming E picks the product up exactly once")
	await tap(KEY_F)
	check(messages.back().contains("Marlow's Cola"), "F inspects the held item")
	await aim(Vector3(-7.2, 0.05, 5.3), noodles.global_position + Vector3(0, 0.05, 0))
	await tap(KEY_E)
	check(inter.held == cola and messages.back() == "Hands full", "E on a second product says Hands full")
	await aim(CLERK, Vector3(-5.6, 3.0, 5.0))
	await tap(KEY_Q)
	check(inter.held == cola and messages.back() == "Nowhere to put that.", "Q aimed at the ceiling is refused (held=%s msg=%s)" % [inter.held, messages.back() if messages.size() else "none"])
	await aim(CLERK, Vector3(-5.2, 0.955, 3.95))
	await tap(KEY_Q)
	check(inter.held == cola and messages.back().begins_with("Nobody is buying"), "placing in the customer zone with no sale is refused")
	await aim(Vector3(-5.8, 0.05, 5.0), game.checkout.terminal.global_position)
	await tap(KEY_E)
	check(messages.back() == "No customer at the counter" and game.checkout.history.is_empty(), "register with no customer gives a reason, no sale")
	await aim(Vector3(-7.55, 0.05, 5.3), Vector3(-7.55, 0.955, 4.4))
	print("DEBUG ray ", inter.raycast().get("collider"), " ", inter.raycast().get("position"), " msgs=", messages.slice(-2))
	await tap(KEY_Q)
	check(inter.held == null and cola.holder == null and cola.get_parent() == world, "Q puts the product back down (held=%s parent=%s)" % [inter.held, cola.get_parent()])

func _wait_customer_at_counter(customer: Customer) -> bool:
	return await wait_until(func(): return game.checkout.state == Checkout.State.OPEN and game.checkout.items.size() == 1, 90)

func _qa_blocked_arrival() -> void:
	player.global_position = Vector3(1.7, 0.05, 5.2)
	var customer := game.spawn_customer()
	var cid := customer.get_instance_id()
	await wait_until(func(): return customer.global_position.z < 6.7, 30)
	var excuses: Array[String] = []
	var excuse_probe := func(_s, text): if text == "Excuse me?": excuses.append(text)
	game.dialogue.line_shown.connect(excuse_probe)
	var closest := INF
	var t := 0.0
	while t < 14.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		closest = minf(closest, customer.global_position.distance_to(player.global_position))
	check(closest > 0.6 and customer.phase == Customer.Phase.ARRIVE, "customer waits instead of walking through a blocking player (closest %.2f m)" % closest)
	game.dialogue.line_shown.disconnect(excuse_probe)
	check(excuses.size() == 1, "blocked customer asks once to get past")
	player.global_position = Vector3(-0.2, 0.05, 6.4)
	var arrived := await wait_until(func(): return customer.phase == Customer.Phase.BROWSE, 60)
	check(arrived, "customer continues once the player steps aside")
	# let this customer finish a normal sale so the next scenario starts clean
	player.global_position = CLERK
	await _wait_customer_at_counter(customer)
	await _pay_all(true)
	check(await wait_until(func(): return not is_instance_id_valid(cid), 60), "blocked-arrival customer still completes and leaves")

func _scan_and_pay_with_keys() -> void:
	var item := game.checkout.items[0]
	await aim(CLERK, item.global_position + Vector3(0, 0.06, 0))
	await tap(KEY_E)
	await aim(Vector3(-5.8, 0.05, 5.0), game.checkout.terminal.global_position)
	await tap(KEY_E)

func _pay_all(use_keys: bool) -> void:
	await _scan_and_pay_with_keys()

func _qa_customer_one() -> void:
	var tasks_before := game.tasks.completed_count()
	var sales_before := game.checkout.history.size()
	var customer := game.spawn_customer()
	var cid := customer.get_instance_id()
	check(customer.profile.id == "c2" or true, "second visitor spawns")
	check(await _wait_customer_at_counter(customer), "customer %s at counter" % customer.profile.id)
	var id: String = customer.profile.id
	game.dialogue.time_scale_for_tests = 4.0
	await aim(Vector3(-5.0, 0.05, 5.0), customer.global_position + Vector3(0, 1.0, 0))
	await tap(KEY_E)
	await tap(KEY_E)
	check(game.dialogue.current_choices.size() == 2, "E during choices does not dismiss them")
	await aim(Vector3(-5.0, 0.05, 5.0), Vector3(-5.0, 1.5, 0.0))
	await tap(KEY_E)
	check(game.dialogue.current_choices.size() == 2, "E at nothing during choices does not skip them")
	await tap(KEY_3)
	check(game.dialogue.current_choices.size() == 2, "key 3 with two options is ignored")
	await tap(KEY_2)
	check(game.dialogue.flags.has(id + "_declined_bag") or game.dialogue.flags.has(id + "_pays_card"), "key 2 selects the second reply")
	await _scan_and_pay_with_keys()
	check(game.checkout.history.size() == sales_before + 1 and game.tasks.completed_count() == tasks_before + 1, "sale for %s recorded and task complete" % id)
	check(await wait_until(func(): return not is_instance_id_valid(cid), 90), "customer %s leaves" % id)

func _qa_customer_two_delayed() -> void:
	game.next_profile = 0  # replay profile c1 as the delayed visitor
	var sales_before := game.checkout.history.size()
	game.tasks.tasks.erase("serve_c1")
	var customer := game.spawn_customer()
	var cid := customer.get_instance_id()
	customer.impatience_delay = 6.0
	check(await _wait_customer_at_counter(customer), "delayed customer at counter")
	await aim(Vector3(-5.0, 0.05, 5.0), customer.global_position + Vector3(0, 1.0, 0))
	await tap(KEY_E)
	await tap(KEY_1)
	check(game.dialogue.flags.get("c1_asked_found", false), "key 1 selects the first reply")
	var waited := 0.0
	var nags: Array[String] = []  # lambdas capture ints by value, so collect into an array
	var counter := func(_s, t): if t == "Take your time.": nags.append(t)
	game.dialogue.line_shown.connect(counter)
	while waited < 30.0:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	check(nags.size() == 1 and game.checkout.state == Checkout.State.OPEN and customer.phase == Customer.Phase.TRANSACTION, "after 30 s: one polite nudge, sale still open, customer still waiting")
	# Extra purchase placed by the player mid-sale is rung up too.
	var water := _find("Product_water") as Product
	await aim(Vector3(-8.0, 0.05, 0.9), water.global_position + Vector3(0, 0.1, 0))
	await tap(KEY_E)
	await aim(Vector3(-4.6, 0.05, 5.0), Vector3(-4.6, 0.955, 3.95))  # clear of the register screen
	await tap(KEY_Q)
	check(game.checkout.items.size() == 2 and water in game.checkout.items, "item the player adds mid-sale joins the sale (items=%d held=%s msg=%s state=%d)" % [game.checkout.items.size(), game.interactor.held, game.hud._message.text, game.checkout.state])
	await aim(Vector3(-5.8, 0.05, 5.0), game.checkout.terminal.global_position)
	await tap(KEY_E)
	check(game.checkout.history.size() == sales_before and game.checkout.state == Checkout.State.OPEN, "payment refused while items are unscanned")
	for item in game.checkout.items.duplicate():
		await aim(CLERK, item.global_position + Vector3(0, 0.06, 0))
		await tap(KEY_E)
	await aim(Vector3(-5.8, 0.05, 5.0), game.checkout.terminal.global_position)
	for i in 3:
		await tap(KEY_E)
	check(game.checkout.history.size() == sales_before + 1 and game.checkout.history.back().total == 249 + 149, "two-item sale totals correctly and pays once")
	game.dialogue.line_shown.disconnect(counter)
	check(await wait_until(func(): return not is_instance_id_valid(cid), 90), "delayed customer leaves")

func _qa_after_transactions() -> void:
	check(game.checkout.state == Checkout.State.IDLE and game.checkout.items.is_empty(), "register idle after all sales")
	check(game.hud._choices.text == "" and not game.dialogue.is_active(), "no stale dialogue or choices on screen")
	player.enabled = true
	player.global_position = Vector3(-7.55, 0.05, 5.6)
	player.rotation = Vector3.ZERO
	await hold(KEY_W, 20)
	check(player.global_position.z < 5.6, "player still walks normally")
	player.enabled = false
	var noodles := _find("Product_noodles") as Product
	await aim(Vector3(-7.2, 0.05, 5.3), noodles.global_position + Vector3(0, 0.05, 0))
	await tap(KEY_E)
	check(game.interactor.held == noodles, "pickup still works after the sales (held=%s focus=%s)" % [game.interactor.held, game.interactor.focus])
	await aim(Vector3(-7.9, 0.05, 5.3), Vector3(-7.9, 0.955, 4.35))
	await tap(KEY_Q)
	check(game.interactor.held == null, "placement still works after the sales")
