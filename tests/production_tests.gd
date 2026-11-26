class_name ProductionTests
extends StoryTests
## Production route uses real customers, payment, chores and the security state machine.
func run_production(market: Node3D) -> void:
	world = market
	game = market.gameplay
	player = market.player
	await _settle()
	Engine.time_scale = 6.0
	game.dialogue.time_scale_for_tests = .15
	var opening := ChapterProgress.new()
	check(opening.load_content(),"production content loads")
	for chapter in ["apartment","route9"]:
		check(opening.current_id() == chapter,"opening chapter " + chapter)
		for event in opening.chapters[opening.index].required:
			opening.record(event)
		opening.advance()
	game.director.delay_scale = .15
	game.begin_production(opening.snapshot())
	var shift := game.director.production
	if shift == null:
		check(false,"production initialized")
		await _finish()
		return
	await _check_market_arrival(shift)
	await _check_handover(shift)
	if not await _chapter("routine"):
		check(false,"handover advances to routine")
		await _finish()
		return
	check(true,"handover advances to routine")
	await _check_rest_of_shift(shift)
	await _finish()

func _check_market_arrival(shift: ProductionShift) -> void:
	await _settle()
	check(player.global_position.z > 12.0 and shift.progress.events.has("market_arrived"),"Route 9 progress starts on the lot")
	await _capture_handover("01-arrival")
	var cues: Array[String] = []
	var record_cue := func(message: String): cues.append(message)
	game.interactor.message.connect(record_cue)
	var door := game.security.front_door
	player.require_mouse_capture = false
	var walk := InputEventKey.new()
	walk.physical_keycode = KEY_W
	walk.pressed = true
	Input.parse_input_event(walk)
	check(await wait_until(func(): return player.global_position.z < 8.06,6), "player reaches the curb ramp from the arrival spawn")
	walk.pressed = false
	Input.parse_input_event(walk)
	await aim(player.global_position, door.handle.global_position)
	check(game.interactor.interact(),"front door opens from the sidewalk using the player ray")
	check(await wait_until(door.is_fully_open, 4), "front leaves clear the entry path")
	check(cues.has("[The front door bell rings.]"),"opening the front door presents the bell caption")
	player.rotation.y = 0.0
	walk.pressed = true
	Input.parse_input_event(walk)
	check(await wait_until(func(): return player.global_position.z < 5.5,5), "player walks through the open front doorway")
	check(await wait_until(func(): return player.global_position.z < 3.6,5), "player clears the entrance")
	walk.pressed = false
	Input.parse_input_event(walk)
	player.enabled = false
	check(await wait_until(door.is_closed,4),"the front door closes behind the player")
	game.interactor.message.disconnect(record_cue)

func _check_handover(shift: ProductionShift) -> void:
	var stock: Array[int] = []
	var stock_triangles := 0
	for node in shift.find_children("*", "MultiMeshInstance3D", true, false):
		var batch: MultiMesh = node.multimesh
		stock.append(batch.instance_count)
		stock_triangles += (batch.mesh.get_faces().size() / 3) * batch.instance_count
	check(stock == [4, 3, 4] and stock_triangles == 1650,"three bottle batches contain 4, 3 and 4 bottles (1,650 triangles)")
	var dina: Customer = shift.staff.dina
	await aim(CLERK, dina.talk.global_position)
	await _capture_handover("02-dina")
	check(game.interactor.interact(),"Dina starts the handover from the player ray")
	check(await wait_until(func(): return shift.progress.events.has("dina_handover"),10),"Dina completes the handover")
	check(await _sale("mara"),"Mara paid and left")
	check(shift.progress.current_id() == "handover","the sale alone leaves the inventory check open")
	shift._use("cooler_counted")
	check(not shift.progress.events.has("cooler_counted"),"inventory refuses unchecked count")
	var cues: Array[String] = []
	var record_cue := func(message: String): cues.append(message)
	game.interactor.message.connect(record_cue)
	for row in ["cooler_row_a","cooler_row_b","cooler_row_c"]:
		await _aim_at_stock(shift, row)
		if row == "cooler_row_b":
			await _capture_handover("03-cooler-row-b")
		check(game.interactor.inspect(),"inspect " + row + " through the player ray")
	check(cues == ["Row A: 4 bottles.","Row B: 3 bottles.","Row C: 4 bottles."],"the three stocked rows report 4, 3 and 4")
	await _aim_at_stock(shift, "cooler_counted")
	check(game.interactor.interact(),"stock card accepts interaction after three rows")
	check(game.dialogue.choose(0),"wrong count is selectable")
	await wait_until(func(): return not game.dialogue.is_active(),10)
	check(not shift.progress.events.has("cooler_counted"),"wrong count rejected")
	check(not cues.has("[The cooler compressor winds down.]"),"wrong count leaves the compressor running")
	check(game.interactor.interact(),"stock card remains usable after an incorrect count")
	game.dialogue.choose(1)
	check(await wait_until(func(): return shift.progress.events.has("cooler_counted"),10),"correct inventory accepted")
	check(cues.count("[The cooler compressor winds down.]") == 1,"correct count triggers one compressor caption")
	game.interactor.message.disconnect(record_cue)

func _aim_at_stock(shift: ProductionShift, id: String) -> void:
	var marker: Interactable = shift.spots[id].node
	await aim(Vector3(marker.global_position.x,.05,marker.global_position.z + 1.35), marker.global_position)
	check(game.interactor.focus == marker,"real ray reaches " + id)

func _capture_handover(shot: String) -> void:
	if "--capture-handover" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless":
		return
	const FOLDER := "res://local/screenshots/handover"
	DirAccess.make_dir_recursive_absolute(FOLDER)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	check(image.save_png(FOLDER.path_join(shot + ".png")) == OK,"capture " + shot)

func _check_rest_of_shift(shift: ProductionShift) -> void:
	for row in ["delivery_a","delivery_b"]:
		shift._use(row)
	check(await wait_until(func(): return not game.dialogue.is_active(),10),"available for invoice")
	shift._use("delivery_checked")
	game.dialogue.choose(1)
	check(await wait_until(func(): return shift.progress.events.has("delivery_checked"),10),"invoice reconciled")
	for i in 3:
		if game.shift.take_stock(game.interactor):
			game.shift.stock_slot(game.shift.slots[i],game.interactor.release_held())
	check(game.shift.filled == 3,"three stock slots filled")
	check(await _sale("ben"),"Ben paid and left")
	check(await _sale("nora"),"Nora paid and left")
	check(await _chapter("closing"),"routine advances")
	if shift.progress.current_id() != "closing":
		return
	shift._use("cash_drop_done")
	check(not shift.progress.events.has("cash_drop_done"),"cash drawer requires carried envelope")
	shift._use("cash_pickup")
	check(game.interactor.held != null,"envelope is held")
	shift._use("cash_drop_done")
	check(game.interactor.held == null and shift.progress.events.has("cash_drop_done"),"cash deposited")
	shift._use("training_binder")
	if game.shift.make_bag(game.interactor):
		game.shift.place_bag(game.interactor.release_held())
	game.shift.lift_latch()
	game.shift.turn_key()
	check(await _sale("ruth"),"Ruth paid and left")
	check(await _sale("leon1"),"Leon first sale")
	check(await _sale("leon2"),"Leon second sale")
	check(await _chapter("outage"),"closing advances")
	if shift.progress.current_id() != "outage":
		return
	game.phone.mark_read("Dina")
	check(shift.progress.has_substantive_evidence(),"binder and phone testimony preserved")
	# Separate security and threat suites exercise live stalking and the actual camera controls.
	# Here isolate the production chapter handoff without the stalker interrupting the test.
	game.director.spawn_enabled = false
	var beats := game.director.beats
	beats.begin()
	beats.blackout()
	game.security.power.flip("main",true)
	game.security.power.flip("security",true)
	beats.finish()
	check(await _chapter("escape"),"security events advance to escape")
	check(await wait_until(func(): return game.director.threat.active,10),"threat begins")
	check(game.checkout.history.size() == 6,"six actual transactions")
	player.global_position = Vector3(1.7,.05,8.3)
	check(await wait_until(func(): return shift.progress.outcome != "",10),"front exit resolves ending")
	check(shift.progress.outcome == "evidence_preserved","evidence ending unlocked")

func _chapter(id: String) -> bool:
	return await wait_until(func(): return game.director.production.progress.current_id() == id,20)

func _sale(id: String) -> bool:
	player.global_position = CLERK
	var checkout := game.checkout
	if not await wait_until(func(): return checkout.state == Checkout.State.OPEN and is_instance_valid(checkout.customer) and checkout.customer.profile.id == id and checkout.items.size() == checkout.customer.profile.items.size(),60):
		return false
	for item in checkout.items:
		checkout.scan(item)
	for attempt in 4:
		if checkout.take_payment():
			break
		await _settle()
	return await wait_until(func(): return game.director.log.has("sale_" + id) and checkout.state == Checkout.State.IDLE,60)

func _finish() -> void:
	Engine.time_scale = 1.0
	print("PRODUCTION TESTS COMPLETE failures=",failures)
	await world.finish_run(1 if failures else 0)
