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
	game.flow.settings.graphics_mode = "performance"
	game.flow.apply_settings()
	game.director.beats.blackout_delay = 120.0
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
	var outage := shift.progress.snapshot()
	await _check_production_archive(shift)
	game.phone.mark_read("Dina")
	check(shift.progress.discoveries.has("dina_statement"),"phone testimony preserved as independent corroboration")
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
	check(shift.progress.current_id() == "escape", "evidence outcome is stored in the finale chapter")
	await _check_production_outcomes(shift)
	await _check_checkpoint_restore(shift)
	await _check_blackout_exit(shift, outage)

func _check_production_archive(shift: ProductionShift) -> void:
	var cctv := game.security.cctv
	check(cctv._history.all(func(tape): return tape.is_empty()) and not cctv._capture_pending.has(true),
		"production has no background camera recording or pending readback")
	check(cctv.feeds.all(func(feed): return feed.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED),
		"camera viewports sleep away from the desk")
	await aim(Vector3(7.4, .05, -4.3), cctv.terminal.global_position)
	check(game.interactor.interact() and cctv.viewing, "use the production CRT through the player ray")
	cctv.settle()
	await _cctv_key(KEY_R)
	check(not cctv.playback, "only the rear hall has an archive")
	await _cctv_key(KEY_D)
	check(cctv.selected == 1 and cctv.viewed.has(1), "switch to the live rear camera")
	await _cctv_key(KEY_R)
	check(cctv.playback and cctv._playback_frames.size() == 4 and cctv._playback_cursor == 0,
		"the production tape opens at its first frame")
	check(not shift.progress.discoveries.has("dvr_clip"), "opening the tape alone does not award evidence")
	for frame in 3:
		await _cctv_key(KEY_RIGHT)
	check(shift.progress.discoveries.has("dvr_clip") and shift.progress.has_substantive_evidence(),
		"the last archived frame corroborates the binder")
	await _cctv_key(KEY_E)
	cctv.settle()
	check(not cctv.viewing and not cctv.playback and game.interactor.enabled and player.camera.current,
		"leaving the archive restores first-person control")
	check(cctv.screen_material.get_shader_parameter("feed") == cctv.feeds[1].viewport.get_texture()
		and cctv._historical_tape().size() == 4, "leaving the archive restores the live texture and retains the tape")

func _cctv_key(key: Key) -> void:
	var input := InputEventKey.new()
	input.physical_keycode = key
	input.pressed = true
	Input.parse_input_event(input)
	await get_tree().process_frame
	input.pressed = false
	Input.parse_input_event(input)

func _check_production_outcomes(shift: ProductionShift) -> void:
	for row in [["escape", "escaped"], ["secured", "rescued"]]:
		shift.progress.outcome = ""
		shift.progress.discoveries.clear()
		check(shift.outcome_for(row[0]) == row[1], "production maps %s to %s without evidence" % [row[0], row[1]])
		check(shift.progress.outcome == row[1], "chapter stores %s outcome" % row[1])
		shift.progress.outcome = ""
	shift.progress.discoveries = {"training_binder": true, "dina_statement": true}
	check(shift.outcome_for("escape") == "evidence_preserved", "escaped player can preserve corroborated evidence")
	shift.progress.outcome = ""
	check(shift.outcome_for("secured") == "evidence_preserved", "rescued player can preserve corroborated evidence")
	shift.progress.outcome = ""
	check(shift.outcome_for("caught") == "caught", "caught maps to caught even with evidence")
	shift.progress.outcome = ""
	shift.progress.discoveries.clear()
	check(shift.outcome_for("unknown") == "unknown" and shift.progress.outcome.is_empty(), "unknown threat outcomes cannot be recorded")

func _check_checkpoint_restore(shift: ProductionShift) -> void:
	var saved := game.checkpoint_data.duplicate(true)
	check(saved.checkpoint == "closing_time" and saved.production.chapter == "escape", "finale checkpoint contains finale chapter state")
	shift.progress.discoveries.clear()
	shift.progress.outcome = ""
	check(game.load_checkpoint(saved), "closing-time checkpoint restores production and threat")
	check(game.director.production.progress.current_id() == "escape" and game.director.threat.active, "restore resumes at the finale with threat active")
	check(game.director.production.progress.discoveries.has("training_binder") and game.director.production.progress.discoveries.has("dina_statement"), "restore retains binder and Dina corroboration")
	game.director.threat.end("caught")
	check(game.director.production.progress.outcome == "caught", "caught signal records production outcome")
	check(game.flow.press("retry"), "the caught card exposes retry")
	check(game.director.production.progress.outcome.is_empty() and game.director.threat.active, "retry restores checkpoint without retaining the ending")

func _check_blackout_exit(shift: ProductionShift, outage: Dictionary) -> void:
	check(shift.progress.restore(outage), "reset to the real outage chapter for the other route")
	var director := game.director
	director.threat.clear_actors()
	director._fired.clear()
	game.tasks.clear()
	director._set_step(StoryDirector.Step.ANOMALY)
	director.beats.begin()
	director.beats.blackout()
	var door := game.security.front_door
	door.set_locked(true, true)
	player.global_position = Vector3(1.7, .05, 8.2)
	await _settle()
	check(shift.progress.outcome.is_empty(), "a locked front door does not validate a blackout exit")
	door.set_locked(false, true)
	player.global_position = Vector3(7.5, .05, 8.2)
	await _settle()
	check(shift.progress.outcome.is_empty(), "a position away from the front exit does not validate escape")
	player.enabled = true
	door.snap(false)
	await aim(Vector3(1.7, .05, 4.82), Vector3(2.24, 1.35, 5.99))
	check(game.interactor.focus is Door.DoorHandle and game.interactor.interact(), "use the real front door during the blackout")
	check(await wait_until(door.is_fully_open, 4), "the front door works with the main breaker off")
	player.rotation.y = PI
	player.camera.rotation.x = 0.0
	var walk := InputEventKey.new()
	walk.physical_keycode = KEY_W
	walk.pressed = true
	Input.parse_input_event(walk)
	check(await wait_until(func(): return shift.progress.outcome == "escaped", 6), "walking out during the blackout reaches the escape ending")
	walk.pressed = false
	Input.parse_input_event(walk)
	check(not game.security.power.main_on and not game.tasks.tasks.has("power") and director.log.has("power_bypassed"),
		"the escape leaves the power off and removes the old objective")

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
