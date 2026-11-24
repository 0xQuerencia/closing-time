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
	player.enabled = false
	player.global_position = CLERK
	var shift := game.director.production
	if shift == null:
		check(false,"production initialized")
		await _finish()
		return
	shift._use("cooler_counted")
	check(not shift.progress.events.has("cooler_counted"),"inventory refuses unchecked count")
	for row in ["cooler_row_a","cooler_row_b","cooler_row_c"]:
		shift._use(row)
	shift._use("cooler_counted")
	check(game.dialogue.choose(0),"wrong count is selectable")
	await wait_until(func(): return not game.dialogue.is_active(),10)
	check(not shift.progress.events.has("cooler_counted"),"wrong count rejected")
	shift._use("cooler_counted")
	game.dialogue.choose(1)
	check(await wait_until(func(): return shift.progress.events.has("cooler_counted"),10),"correct inventory accepted")
	shift._use("dina_handover")
	check(await _sale("mara"),"Mara paid and left")
	check(await _chapter("routine"),"handover advances")
	if shift.progress.current_id() != "routine":
		await _finish()
		return
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
		await _finish()
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
		await _finish()
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
	await _finish()

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
