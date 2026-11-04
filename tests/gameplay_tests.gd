class_name GameplayTests
extends Node
## Headless M2 checks against the real world scene: interaction, checkout, dialogue, tasks and NPC cycles.
const TIME_SCALE := 4.0
const CLERK := Vector3(-5.6, 0.05, 5.0)
var world: Node3D
var game: Gameplay
var player: CharacterBody3D
var failures := 0

func run(market: Node3D) -> void:
	world = market
	game = market.gameplay
	player = market.player
	await _settle()
	game.dialogue.time_scale_for_tests = 0.0
	await _test_bindings()
	await _test_aiming_and_pickup()
	await _test_placement()
	await _test_bell()
	_test_dialogue()
	_test_tasks()
	await _test_manual_sale()
	await _test_routes()
	game.dialogue.time_scale_for_tests = 1.0
	Engine.time_scale = TIME_SCALE
	await _test_customer_cycles()
	Engine.time_scale = 1.0
	print("GAMEPLAY TESTS COMPLETE failures=", failures)
	await world.finish_run(1 if failures else 0)

func check(condition: bool, label: String) -> void:
	if condition:
		print("GAMEPLAY TEST PASS: ", label)
	else:
		push_error("GAMEPLAY TEST FAIL: " + label)
		failures += 1

func _settle(frames := 3) -> void:
	for i in frames:
		await get_tree().physics_frame

func aim(from: Vector3, target: Vector3) -> void:
	player.global_position = from
	var d := target - (from + Vector3(0, 1.62, 0))
	player.rotation = Vector3(0, atan2(-d.x, -d.z), 0)
	player.camera.rotation = Vector3(atan2(d.y, Vector2(d.x, d.z).length()), 0, 0)
	await _settle()

func wait_until(condition: Callable, seconds: float) -> bool:
	var start := Time.get_ticks_msec()
	while not condition.call():
		if Time.get_ticks_msec() - start > seconds * 1000.0:
			return false
		await get_tree().physics_frame
	return true

func _test_bindings() -> void:
	for action in [GameInput.INTERACT, GameInput.INSPECT, GameInput.DROP, &"choice_1"]:
		check(InputMap.has_action(action), "input action " + String(action))
	player.camera.rotation = Vector3.ZERO
	player.global_position = Vector3(-8.0, 0.05, 2.0)
	player.rotation.y = PI / 2.0  # face the side wall
	await _settle()
	check(game.interactor.focus == null and not game.interactor.interact(), "nothing nearby: interact does nothing")
	check(game.interactor.current_prompt().text == "", "no prompt without a target")

func _test_aiming_and_pickup() -> void:
	var cola := _find("Product_cola")
	var noodles := _find("Product_noodles")
	await aim(Vector3(-7.55, 0.05, 5.3), cola.global_position + Vector3(0, 0.06, 0))
	check(game.interactor.focus == cola, "ray focuses a product within reach")
	var prompt := game.interactor.current_prompt()
	check(prompt.available and prompt.text.begins_with("Pick up Marlow's Cola"), "prompt names verb and item: " + prompt.text)
	check(game.interactor.inspect() and cola.inspect(game.interactor).contains("$1.79"), "inspect reports price")
	await aim(Vector3(-7.55, 0.05, 6.9), cola.global_position + Vector3(0, 0.06, 0))
	check(game.interactor.focus == null, "targets beyond reach are ignored")
	var hidden := Product.new().setup("water", world)
	world.add_child(hidden)
	hidden.global_position = Vector3(-9.35, 1.0, 2.0)
	await aim(Vector3(-8.2, 0.05, 2.0), hidden.global_position + Vector3(0, 0.06, 0))
	check(game.interactor.focus == null, "wall occludes a product behind it")
	hidden.queue_free()
	await aim(Vector3(-7.55, 0.05, 5.3), cola.global_position + Vector3(0, 0.06, 0))
	check(game.interactor.interact() and game.interactor.held == cola, "interact picks the product up")
	check(cola.get_parent() == player.camera, "held product follows the camera")
	await aim(Vector3(-7.2, 0.05, 5.3), noodles.global_position + Vector3(0, 0.05, 0))
	check(not game.interactor.interact() and game.interactor.current_prompt().text == "Hands full", "second pickup is refused with a reason")

func _test_placement() -> void:
	var cola := game.interactor.held
	# Counter end, away from the customer zone.
	await aim(Vector3(-7.9, 0.05, 5.3), Vector3(-7.9, 0.955, 4.35))
	check(game.interactor.place_held(), "held product can be placed on a surface")
	check(game.interactor.held == null and absf(cola.global_position.y - 0.955) < 0.03, "placed product rests on the counter top")
	check(game.interactor.pick_up(cola), "placed product can be picked up again")
	await aim(CLERK, Vector3(-5.2, 0.955, 3.95))
	check(not game.interactor.place_held() and game.interactor.held == cola, "customer zone refuses items with nobody buying")
	await aim(CLERK, Vector3(-5.2, 0.0, 5.9))
	cola.place_at(Vector3(-7.55, 0.955, 4.4), 0.0)
	game.interactor.held = null
	check(cola.holder == null, "product returned to stock")

func _test_bell() -> void:
	var bell: ServiceBell = null
	for child in game.checkout.get_children():
		if child is ServiceBell:
			bell = child
	check(bell != null, "counter has a service bell")
	var rings: Array[int] = []
	bell.rung.connect(func(): rings.append(1))
	await aim(Vector3(-6.75, 0.05, 5.0), bell.global_position + Vector3(0, 0.06, 0))
	check(game.interactor.focus == bell and game.interactor.current_prompt().text == "Ring service bell", "aiming at the bell offers Ring")
	game.interactor.interact()
	check(rings.size() == 1, "interacting rings the bell")

func _test_dialogue() -> void:
	var d := game.dialogue
	var lines: Array[String] = []
	var capture := func(speaker, text): lines.append("%s|%s" % [speaker, text])
	d.line_shown.connect(capture)
	var done: Array[String] = []
	d.finished.connect(func(id): done.append(id))
	check(d.start("mara_thanks") and done == ["mara_thanks"], "scripted conversation runs to completion")
	check(lines == ["Mara|Night, hon. Get home safe.", "Jamie|You too."], "lines arrive in order")
	d.time_scale_for_tests = 1.0
	d.start("mara_talk")
	check(d.is_active() and d.current_choices.size() == 2, "choices wait for the player")
	check(not d.choose(5), "invalid choice index is ignored")
	check(d.choose(0) and d.flags.get("mara_not_anymore", false), "choice sets a flag")
	d.cancel()
	check(not d.is_active() and done.back() == "mara_talk", "cancel ends conversation and notifies")
	d.time_scale_for_tests = 0.0
	d.line_shown.disconnect(capture)

func _test_tasks() -> void:
	var t := TaskManager.new()
	add_child(t)
	var completed: Array[String] = []
	t.task_completed.connect(func(id): completed.append(id))
	t.add_task("x", "Test", [{"id": "a", "text": "A"}, {"id": "b", "text": "B"}])
	check(t.complete_objective("x", "a") and completed.is_empty(), "first objective does not finish the task")
	check(not t.complete_objective("x", "a") and not t.complete_objective("x", "zzz"), "repeat and unknown objectives are rejected")
	check(t.complete_objective("x", "b") and completed == ["x"] and t.is_complete("x"), "task completes only when every objective is done")
	t.queue_free()

func _find(node_name: String) -> Node:
	for child in world.get_children():
		if child.name == node_name:
			return child
	return null

func _test_manual_sale() -> void:
	var checkout := game.checkout
	var cola := _find("Product_cola") as Product
	var terminal := checkout.terminal
	var sales: Array[Dictionary] = []
	checkout.sale_completed.connect(func(tx): sales.append(tx))
	check(not terminal.can_interact(null) and terminal.blocked_reason(null) == "No customer at the counter", "register refuses payment with no customer")
	var stand_in := Node3D.new()
	add_child(stand_in)
	check(checkout.open_sale(stand_in) and not checkout.open_sale(stand_in), "only one sale can be open")
	check(terminal.blocked_reason(null) == "Nothing on the counter yet", "register waits for items")
	cola.place_at(checkout.drop_point(0), 0.0)
	check(cola in checkout.items and cola.checkout == checkout, "item placed in the zone joins the sale")
	check(terminal.blocked_reason(null).begins_with("Scan the items first"), "payment blocked until scanned")
	await aim(CLERK, cola.global_position + Vector3(0, 0.06, 0))
	check(game.interactor.current_prompt().text.begins_with("Scan Marlow's Cola"), "aiming at counter item offers scan")
	for i in 5:  # spam
		game.interactor.interact()
	check(cola.scanned and checkout.scanned_count() == 1 and checkout.total_cents() == 179, "scan counts once and records price")
	await aim(Vector3(-5.8, 0.05, 5.0), terminal.global_position)
	check(game.interactor.focus == terminal and game.interactor.current_prompt().text.contains("$1.79"), "register prompt shows the total")
	for i in 5:
		game.interactor.interact()
	check(sales.size() == 1 and sales[0].total == 179 and sales[0].items == ["cola"], "payment completes exactly one transaction")
	check(checkout.state == Checkout.State.PAID and not checkout.take_payment(), "completed sale cannot be paid twice")
	cola.queue_free()
	checkout.release_items()
	checkout.close_sale()
	check(checkout.state == Checkout.State.IDLE and checkout.items.is_empty(), "register resets after the customer leaves")
	stand_in.queue_free()

func _test_routes() -> void:
	var probe := CharacterBody3D.new()
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.26
	capsule.height = 1.74
	shape.shape = capsule
	shape.position.y = 0.87
	probe.add_child(shape)
	probe.collision_mask = 1
	add_child(probe)
	game.security.front_door.snap(true)  # customers push the doors open; sweep with them open
	await get_tree().physics_frame
	await get_tree().physics_frame
	for profile in game.profiles:
		var path: Array[Vector3] = [profile.start]
		for leg in ["arrive", "browse", "queue", "leave", "car"]:
			if not profile.route.has(leg):
				continue
			path.append_array(profile.route[leg])
		var clear := true
		for i in range(path.size() - 1):
			var from := Vector3(path[i].x, 0.04, path[i].z)
			var motion := Vector3(path[i + 1].x - from.x, 0, path[i + 1].z - from.z)
			if probe.test_move(Transform3D(Basis.IDENTITY, from), motion):
				clear = false
				push_error("route blocked for %s between %s and %s" % [profile.id, path[i], path[i + 1]])
		check(clear, "capsule can walk every leg of route " + profile.id)
	probe.queue_free()

## Scans every item on the counter and takes payment through the real interactor. Returns payment attempts.
func scan_all_and_pay(max_attempts := 4) -> int:
	var checkout := game.checkout
	for item in checkout.items.duplicate():
		await aim(Vector3(item.global_position.x + 0.1, 0.05, 5.0), item.global_position + Vector3(0, 0.06, 0))
		game.interactor.interact()
	var sales := checkout.history.size()
	var attempts := 0
	await aim(Vector3(-5.8, 0.05, 5.0), checkout.terminal.global_position)
	while checkout.history.size() == sales and attempts < max_attempts:
		game.interactor.interact()
		attempts += 1
		await get_tree().physics_frame
	return attempts

func _test_customer_cycles() -> void:
	var checkout := game.checkout
	var line_log: Array[String] = []
	game.dialogue.line_shown.connect(func(s, t): line_log.append("%s|%s" % [s, t]))
	var failures_seen: Array[int] = []
	checkout.payment_failed.connect(func(left): failures_seen.append(left))
	for round_index in 2:
		var delayed := round_index == 1
		var customer := game.spawn_customer()
		check(customer != null, "customer %d enters" % (round_index + 1))
		customer.impatience_delay = 3.0
		var id: String = customer.profile.id
		var customer_id := customer.get_instance_id()
		var sales_before := checkout.history.size()
		check(await wait_until(func(): return checkout.state == Checkout.State.OPEN and checkout.items.size() == 2, 90), "%s reaches the counter with two items" % id)
		check(customer.phase == Customer.Phase.TRANSACTION and checkout.customer == customer, "phase is TRANSACTION at the counter")
		check(game.tasks.tasks["serve_" + id].objectives[0].done and not game.tasks.is_complete("serve_" + id), "task: at counter done, not complete yet")
		await aim(Vector3(-5.0, 0.05, 5.0), customer.global_position + Vector3(0, 1.0, 0))
		check(game.interactor.focus == customer.talk, "player can aim at the customer")
		if not delayed:
			game.dialogue.time_scale_for_tests = 1.0
			game.interactor.interact()
			check(game.dialogue.is_active() and game.dialogue.current_choices.size() == 2, "talking offers two replies")
			game.dialogue.choose(1)
			check(game.dialogue.flags.has("mara_just_covering"), "reply sets a story flag")
		else:
			await get_tree().create_timer(4.5).timeout
			check(line_log.any(func(l): return l.ends_with("No rush.")), "customer waits patiently and speaks up when delayed")
			check(checkout.state == Checkout.State.OPEN and not game.tasks.is_complete("serve_" + id), "no timer completes the sale")
		var attempts := await scan_all_and_pay()
		check(checkout.items.all(func(p): return p.scanned) or checkout.history.size() == sales_before + 1, "both items scanned")
		check(checkout.history.size() == sales_before + 1, "transaction %d recorded" % (round_index + 1))
		check(attempts == (2 if delayed else 1), "payment took %d attempt(s): Ben's reader fails once, Mara's does not" % attempts)
		check(game.tasks.is_complete("serve_" + id), "task completes after the sale")
		var gone := await wait_until(func(): return not is_instance_id_valid(customer_id), 90)
		check(gone, "customer %s leaves and is removed" % id)
		check(checkout.state == Checkout.State.IDLE, "register is idle again")
	check(failures_seen == [0], "exactly one reader failure happened, for Ben")
	check(game.customers_served == 3 and game.tasks.completed_count() == 2, "two customers served end to end")
	check(game.next_profile == 2, "story customers beyond Ben are left for the director")

## Real-renderer screenshots of the sale in progress: local/screenshots/gameplay_*.png
func capture(market: Node3D) -> void:
	world = market
	game = market.gameplay
	player = market.player
	DirAccess.make_dir_recursive_absolute("res://local/screenshots")
	game.dialogue.time_scale_for_tests = 4.0
	var customer := game.spawn_customer()
	await wait_until(func(): return game.checkout.state == Checkout.State.OPEN, 60)
	await get_tree().create_timer(0.5).timeout
	var shots := [
		["gameplay_1_counter", CLERK, Vector3(-5.2, 1.0, 3.6), false],
		["gameplay_2_scan_prompt", CLERK, game.checkout.items[0].global_position + Vector3(0, 0.06, 0), true],
		["gameplay_3_register", Vector3(-5.8, 0.05, 5.0), game.checkout.terminal.global_position, false],
	]
	for shot in shots:
		await aim(shot[1], shot[2])
		if shot[3]:
			game.interactor.refresh_focus()
		await get_tree().create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		var err := get_viewport().get_texture().get_image().save_png("res://local/screenshots/%s.png" % shot[0])
		print("CAPTURE ", shot[0], " status=", err, " focus=", game.interactor.current_prompt())
	await aim(CLERK, game.checkout.items[0].global_position + Vector3(0, 0.06, 0))
	game.interactor.interact()
	await aim(Vector3(-5.8, 0.05, 5.0), game.checkout.terminal.global_position)
	game.interactor.interact()
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://local/screenshots/gameplay_4_paid.png")
	var cid := customer.get_instance_id()
	await wait_until(func(): return not is_instance_id_valid(cid), 60)  # exit with no suspended customer coroutine
	await world.finish_run(0)
