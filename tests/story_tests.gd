class_name StoryTests
extends GameplayTests
## M3 story regression tests: state machine, once-only triggers, chores, clues and a full accelerated night.
const TIME_SCALE_FAST := 8.0

func run_story(market: Node3D) -> void:
	world = market
	game = market.gameplay
	player = market.player
	await _settle()
	game.dialogue.time_scale_for_tests = 0.0
	if not "--night-only" in OS.get_cmdline_user_args():
		_test_clock_and_phone()
		await _test_chores()
		await _test_clues()
		await _test_state_machine()
		game.shift.reset()
		game.clues.reset()
		game.director._chores_done.clear()
	game.dialogue.time_scale_for_tests = 1.0
	Engine.time_scale = TIME_SCALE_FAST
	await _test_full_night()
	Engine.time_scale = 1.0
	print("STORY TESTS COMPLETE failures=", failures)
	await world.finish_run(1 if failures else 0)

# --- clock and phone ---------------------------------------------------------------------------

func _test_clock_and_phone() -> void:
	var clock := StoryClock.new()
	check(clock.text() == "11:24 PM", "shift starts at 11:24 PM")
	check(clock.advance_to(23, 31) and clock.text() == "11:31 PM", "clock advances forward")
	check(not clock.advance_to(23, 30) and clock.text() == "11:31 PM", "clock never runs backward")
	check(clock.advance_to(0, 4) and clock.text() == "12:04 AM", "clock crosses midnight")
	var phone := PhoneModel.new()
	check(phone.deliver("a", "Dina", "hello", "11:26 PM"), "message delivered")
	check(not phone.deliver("a", "Dina", "hello again", "11:27 PM") and phone.message_count() == 1, "same id is never delivered twice")
	check(not phone.deliver("b", "Nobody", "x", "11:27 PM"), "unknown thread rejected")
	check(phone.unread_count() == 1 and phone.unread_count("Kay") == 0, "unread counts per thread")
	phone.mark_read("Dina")
	check(phone.unread_count() == 0, "reading a thread clears its unread count")
	phone.deliver("c", "Kay", "mine", "11:30 PM", true)
	check(phone.unread_count() == 0, "your own messages are never unread")

# --- state machine -----------------------------------------------------------------------------

var _fakes: Array[Customer] = []

func _fake_customer(id: String) -> Customer:
	var c := Customer.new()
	c.profile = {"id": id}
	_fakes.append(c)
	return c

func _fresh_director() -> StoryDirector:
	var d := StoryDirector.new()
	game.add_child(d)
	d.spawn_enabled = false
	d.delay_scale = 0.0
	d.phone = PhoneModel.new()
	d.clock = StoryClock.new()
	d.game = game
	return d

func _test_state_machine() -> void:
	var d := _fresh_director()
	d.phone = PhoneModel.new()
	# Out-of-order events must not advance anything.
	d._on_customer_finished(_fake_customer("ben"))
	d._on_customer_finished(_fake_customer("leon2"))
	check(d.step == StoryDirector.Step.IDLE and d.log.is_empty(), "events before the shift starts do nothing")
	d._spawn("mara", StoryDirector.Step.MARA)
	d._spawn("mara", StoryDirector.Step.MARA)
	check(d.spawn_log == ["mara"], "a visitor spawns once")
	d._on_customer_finished(_fake_customer("ben"))
	check(d.step == StoryDirector.Step.MARA, "Ben finishing during Mara's visit is ignored")
	d._on_customer_finished(_fake_customer("mara"))
	check(d.step == StoryDirector.Step.BEN, "Mara finishing moves the night to Ben")
	d._on_customer_finished(_fake_customer("mara"))
	await get_tree().process_frame
	await get_tree().process_frame
	check(d.log.count("spawn_ben") == 1 and d.log.count("msg_dina_2") == 1, "a repeated finish does not repeat Dina's text or Ben's arrival")
	d._on_customer_finished(_fake_customer("ben"))
	await get_tree().process_frame
	await get_tree().process_frame
	check(d.step == StoryDirector.Step.LEON_1 or d.step == StoryDirector.Step.WORK, "Ben finishing opens the work stretch")
	d._chores_done = {}
	d._set_step(StoryDirector.Step.LEON_1_AWAY)
	d._away = 0.0
	d._process(5.0)
	check(d.step == StoryDirector.Step.LEON_1_AWAY, "Leon waits: no chores, only 5 s")
	d._chores_done = {"restock": true, "trash": true}
	d._process(6.0)
	check(d.step == StoryDirector.Step.LEON_2 and d.spawn_log.count("leon2") == 1, "two chores plus 11 s brings him back, once")
	d._process(100.0)
	check(d.spawn_log.count("leon2") == 1, "no second return")
	var timeout := _fresh_director()
	timeout._set_step(StoryDirector.Step.LEON_1_AWAY)
	timeout._process(StoryDirector.LEON_RETURN_MAX_AWAY + 1.0)
	check(timeout.spawn_log == ["leon2"], "with no chores done he still returns after 90 s (no softlock)")
	d.game.clues.active = false
	d._on_customer_finished(_fake_customer("leon2"))
	check(d.step == StoryDirector.Step.ANOMALY and game.clues.active, "Leon's second visit ends in the anomaly")
	d._on_customer_finished(_fake_customer("leon2"))
	await get_tree().process_frame
	await get_tree().process_frame
	check(d.log.count("msg_kay_3") <= 1 and d.log.count("msg_dina_4") <= 1, "anomaly texts arrive once")
	check(d.phone.has_delivered("dina_4") and d.phone.has_delivered("kay_3") and d.phone.has_delivered("kay_2"), "all three late messages were sent")
	check(d.phone.threads["Kay"].any(func(e): return e.me), "Jamie's own text to Kay appears in the thread")
	d.queue_free()
	timeout.queue_free()
	for fake in _fakes:
		fake.free()  # stand-ins never entered the tree
	_fakes.clear()

# --- chores through the real interactor -------------------------------------------------------

func press_on(from: Vector3, target: Vector3) -> void:
	await aim(from, target)
	game.interactor.interact()

func do_restock() -> void:
	for i in 3:
		await press_on(Vector3(5.75, 0.05, 0.3), ShiftTasks.CARTON_POINT + Vector3(0, 0.15, 0))
		var slot: ShiftTasks.RestockSlot = game.shift.slots[i]
		await press_on(Vector3(slot.position.x, 0.05, 3.4), slot.position + Vector3(0, 0.2, 0))

func do_trash() -> void:
	await press_on(Vector3(-7.7, 0.05, 5.3), ShiftTasks.BIN_POINT + Vector3(0, 0.4, 0))
	await aim(Vector3(4.25, 0.05, -4.2), ShiftTasks.BAG_SPOT + Vector3(0, 0.08, 0))
	game.interactor.interact()

func do_latch() -> void:
	await press_on(Vector3(4.25, 0.05, -4.9), ShiftTasks.LATCH_POINT)
	await press_on(Vector3(4.25, 0.05, -4.9), ShiftTasks.LATCH_POINT + Vector3(0, -0.13, 0))

func _test_chores() -> void:
	var shift := game.shift
	var done: Array[String] = []
	game.tasks.task_completed.connect(func(id): done.append(id))
	game.tasks.add_task("restock", "Stock three products", [{"id": "s1", "text": "1"}, {"id": "s2", "text": "2"}, {"id": "s3", "text": "3"}])
	game.tasks.add_task("trash", "Bag the trash", [{"id": "bag", "text": "bag"}, {"id": "rear", "text": "rear"}])
	game.tasks.add_task("latch", "Check the rear-door latch", [{"id": "lift", "text": "lift"}, {"id": "lock", "text": "lock"}])
	shift.restocked.connect(func(n): game.tasks.complete_objective("restock", "s%d" % n))
	shift.trash_bagged.connect(func(): game.tasks.complete_objective("trash", "bag"))
	shift.trash_placed.connect(func(): game.tasks.complete_objective("trash", "rear"))
	shift.latch_lifted.connect(func(): game.tasks.complete_objective("latch", "lift"))
	shift.latch_locked.connect(func(): game.tasks.complete_objective("latch", "lock"))
	# Latch: the key must not turn until the latch is lifted.
	await press_on(Vector3(4.25, 0.05, -4.9), ShiftTasks.LATCH_POINT + Vector3(0, -0.13, 0))
	check(not shift.locked and game.interactor.current_prompt().text == "Stuck. Lift the latch first.", "key refuses to turn before the latch is lifted")
	await do_latch()
	check(shift.latch_is_lifted and shift.locked and game.tasks.is_complete("latch"), "lift then turn completes the latch check")
	for i in 3:
		game.interactor.interact()  # spam on the already locked door
	check(done.count("latch") == 1, "latch task completes exactly once")
	# Trash: placing without a bag is refused; bag then place completes.
	await aim(Vector3(4.25, 0.05, -4.2), ShiftTasks.BAG_SPOT + Vector3(0, 0.08, 0))
	check(game.interactor.current_prompt().available == false, "no drop prompt without a bag")
	await do_trash()
	check(shift.bag_made and shift.bag_placed and game.tasks.is_complete("trash") and done.count("trash") == 1, "bag the trash completes once")
	# Restock: three different gaps; wrong item refused.
	await press_on(Vector3(5.75, 0.05, 0.3), ShiftTasks.CARTON_POINT + Vector3(0, 0.15, 0))
	var held := game.interactor.held
	check(held != null and held.product_id in ShiftTasks.STOCK_IDS, "taking stock puts a product in hand")
	await aim(Vector3(-6.33, 0.05, 3.4), shift.slots[0].position + Vector3(0, 0.2, 0))
	check(game.interactor.current_prompt().available and game.interactor.current_prompt().text.begins_with("Stock "), "a shelf gap offers to take stock")
	game.interactor.release_held().queue_free()
	await do_restock()
	check(shift.filled == 3 and game.tasks.is_complete("restock") and done.count("restock") == 1, "three gaps filled completes the restock once")
	await aim(Vector3(-6.33, 0.05, 3.4), shift.slots[0].position + Vector3(0, 0.2, 0))
	check(not game.interactor.current_prompt().available, "a filled gap offers nothing more")
	check(done.size() == 3, "each chore finished exactly once: " + str(done))

# --- clues -------------------------------------------------------------------------------------

func _test_clues() -> void:
	var clues := game.clues
	var seen: Array[String] = []
	clues.clue_seen.connect(func(id): seen.append(id))
	await press_on(Vector3(6.2, 0.05, -3.1), Vector3(5.25, 1.45, -3.1))
	check(game.hud._message.text.contains("All in their place") and seen.is_empty(), "before the anomaly the hooks look normal and prove nothing")
	check(clues._spare_key.visible and not clues._prints[0].visible, "normal state: key on its hook, no prints")
	clues.activate()
	check(not clues.activate(), "the anomaly only fires once")
	check(not clues._spare_key.visible and clues._prints[0].visible and clues._envelope.position.is_equal_approx(Clues.ENVELOPE_MOVED), "after: hook empty, envelope moved, prints visible")
	await press_on(Vector3(6.2, 0.05, -3.1), Vector3(5.25, 1.45, -3.1))
	check(seen == ["spare_key"] and game.hud._message.text.contains("SPARE hook is empty"), "key hooks clue found by walking up to them")
	await press_on(Vector3(7.7, 0.05, -4.2), Clues.ENVELOPE_MOVED + Vector3(0, 0.05, 0))
	check(seen.has("cash_envelope"), "cash envelope clue found")
	await press_on(Vector3(4.3, 0.05, -2.2), Vector3(4.3, 0.05, -3.5))
	check(seen.has("boot_prints"), "boot prints clue found")
	await press_on(Vector3(6.2, 0.05, -3.1), Vector3(5.25, 1.45, -3.1))
	check(seen.size() == 3, "each clue registers once")

# --- the whole night ---------------------------------------------------------------------------

func _serve(id: String, talk_choice := -1, settle_line := "") -> Customer:
	var customer: Customer = null
	check(await wait_until(func(): return game.checkout.state == Checkout.State.OPEN and game.checkout.customer != null and game.checkout.customer.profile.id == id and game.checkout.items.size() == game.checkout.customer.profile.items.size(), 120), "%s reaches the counter" % id)
	customer = game.checkout.customer
	if talk_choice >= 0:
		await aim(Vector3(-5.0, 0.05, 5.0), customer.global_position + Vector3(0, 1.0, 0))
		game.interactor.interact()
		check(game.dialogue.current_choices.size() > 0, "%s offers replies" % id)
		game.dialogue.choose(talk_choice)
		if settle_line != "":  # paying mid-sentence would cut the exchange off, so let it finish
			await wait_until(func(): return story_lines.has(settle_line), 40)
	var attempts := await scan_all_and_pay()
	check(game.checkout.history.back().items.size() == customer.profile.items.size(), "%s: sale rang up every item (%d tries)" % [id, attempts])
	return customer

var story_lines: Array[String] = []

func _test_full_night() -> void:
	game.tasks.tasks.clear()
	game.checkout.history.clear()
	game.next_profile = 0
	var d := game.director
	d.spawn_enabled = true
	d.delay_scale = 0.1
	var lines := story_lines
	game.dialogue.line_shown.connect(func(s, t): lines.append("%s|%s" % [s, t]))
	game.hud.visible = true
	d.start()
	check(not d.start(), "the night starts once")
	check(game.phone.has_delivered("dina_1") or await wait_until(func(): return game.phone.has_delivered("dina_1"), 20), "Dina's first text arrives")
	await _serve("mara", 1)
	await _serve("ben", 0)
	check(lines.has("Mara|Still here? Thought you had Fridays off.") and game.dialogue.flags.has("mara_just_covering"), "Mara's lines and reply")
	check(await wait_until(func(): return d.step == StoryDirector.Step.WORK, 60), "after Mara and Ben the night is in the work stretch")
	var ben_lines := lines.has("Ben|Again?")
	check(game.phone.has_delivered("dina_2"), "Dina's latch text came after Mara")
	check(d.flags.get("sale_1_completed", false) and d.flags.get("sale_2_completed", false), "both opening sales flagged")
	check(ben_lines, "Ben reacted to the card reader failing")
	check(await wait_until(func(): return d.step == StoryDirector.Step.LEON_1, 60), "Leon's first visit begins")
	await do_latch()
	await do_trash()
	await _serve("leon1", 0)
	check(lines.has("Leon|What time do you close?") or await wait_until(func(): return lines.has("Leon|What time do you close?"), 40), "Leon asks when you close")
	check(await wait_until(func(): return d.step == StoryDirector.Step.LEON_1_AWAY, 60), "Leon leaves after the first visit")
	check(await wait_until(func(): return d.step == StoryDirector.Step.LEON_2, 90), "Leon returns once two chores are done")
	await _serve("leon2", 0, "Leon|It is a popular water.")
	check(lines.has("Leon|No, I wasn't.") and game.dialogue.flags.get("leon2_confronted", false), "second visit: he denies having been here")
	check(await wait_until(func(): return d.step == StoryDirector.Step.ANOMALY, 60), "the anomaly follows his second visit")
	check(game.clues.active and d.flags.get("leon_visit_2", false), "clues are active and the visit is flagged")
	check(await wait_until(func(): return game.phone.has_delivered("dina_4"), 60), "Dina's warning arrives last")
	# Order of the whole night, each beat exactly once.
	var order := ["msg_dina_1", "spawn_mara", "sale_mara", "msg_dina_2", "spawn_ben", "sale_ben", "msg_kay_1", "spawn_leon1", "sale_leon1", "spawn_leon2", "sale_leon2", "msg_kay_2", "msg_kay_3", "msg_dina_4"]
	var last := -1
	var ordered := true
	for entry in order:
		var at := d.log.find(entry)
		if at == -1 or d.log.count(entry) != 1 or at < last:
			ordered = false
			push_error("story order broken at " + entry + " in " + str(d.log))
			break
		last = at
	check(ordered, "every beat happened exactly once and in order")
	check(game.phone.message_count() == 7, "seven messages in total: %d" % game.phone.message_count())
	check(game.shift.locked and game.shift.bag_placed, "chores done earlier stayed done (locked=%s lifted=%s bag_made=%s bag_placed=%s chores=%s held=%s)" % [game.shift.locked, game.shift.latch_is_lifted, game.shift.bag_made, game.shift.bag_placed, d._chores_done.keys(), game.interactor.held])
	# Leon is recognisably the same man in different clothes.
	var p1: Dictionary = game.profiles[2]
	var p2: Dictionary = game.profiles[3]
	check(p1.items == p2.items and p1.model == p2.model and p1.mannerism == p2.mannerism, "same water, same body, same glance both visits")
	check(p1.outfit != p2.outfit and not p1.get("cap", false) and p2.get("cap", false), "different clothes, and a cap the second time")
	d.delay_scale = 1.0
