class_name TimedPlaythrough
extends StoryTests
## Scripted bot that plays M1-M4 at roughly human pace in real time (Engine.time_scale 1, real renderer) and
## reports wall-clock time per beat. It walks at the player's real speed and pauses to read and aim, but it is a
## script, not a person: treat the numbers as a model of a competent first-time player, not a playtest.
## Run: godot --path . --resolution 1280x720 -- --timed-playthrough  [--pace=fast|slow]
const WALK_SPEED := 1.9
const PATH_DETOUR := 1.25  # real routes bend around shelves
const OUT := "res://local/screenshots/timing"
var pace_scale := 1.0
var t0 := 0
var marks: Array = []
var ending_plan := "secured"
var play := 0.0  # seconds of play with every frame clamped to 100 ms, so one-off loading hitches don't count
var frames := 0
var worst_frame := 0.0

func _process(delta: float) -> void:
	if t0 == 0:
		return
	play += minf(delta, 0.1)
	frames += 1
	worst_frame = maxf(worst_frame, delta)

func _seconds() -> float:
	return play

func _mark(label: String) -> void:
	marks.append({"at": _seconds(), "label": label})
	print("TIMING %6.1fs (wall %5.1fs, %d frames)  %s" % [_seconds(), (Time.get_ticks_msec() - t0) / 1000.0, frames, label])

func _think(seconds: float) -> void:
	await get_tree().create_timer(seconds * pace_scale).timeout

func _walk_to(pos: Vector3, speed := WALK_SPEED) -> void:
	player.enabled = false  # the bot owns the body; leaving the desk hands control back, which would let physics shove it
	var from := player.global_position
	var seconds := from.distance_to(pos) * PATH_DETOUR / speed * pace_scale
	var elapsed := 0.0
	while elapsed < seconds:
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
		player.global_position = from.lerp(pos, clampf(elapsed / seconds, 0.0, 1.0))
		player.velocity = (pos - from).normalized() * speed
	player.velocity = Vector3.ZERO
	player.global_position = pos

func _look_press(from: Vector3, target: Vector3, read := 0.7) -> void:
	await _walk_to(from)
	await aim(from, target)
	await _think(read)
	game.interactor.interact()
	await _think(0.25)

func _shot(shot_name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(OUT)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OUT, shot_name])

func _pace_arg() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ending="):
			ending_plan = arg.trim_prefix("--ending=")
		if arg.begins_with("--pace="):
			match arg.trim_prefix("--pace="):
				"fast":
					pace_scale = 0.6
				"slow":
					pace_scale = 1.6

func _read_phone() -> void:
	await _think(2.2)  # glance at the new text

func run_timed(market: Node3D) -> void:
	world = market
	game = market.gameplay
	player = market.player
	_pace_arg()
	game.hud.visible = true
	for i in 40:
		await get_tree().process_frame
	await _settle()
	game.tasks.tasks.clear()
	player.global_position = CLERK
	var d := game.director
	d.event_logged.connect(func(entry): _mark("event " + entry))
	t0 = Time.get_ticks_msec()
	game.security.cctv.feed_viewed.connect(func(i): _mark("cctv feed_viewed %d step=%d live=%s" % [i, d.step, game.security.cctv.is_live()]))
	d.start()
	_mark("shift starts (pace x%.1f)" % pace_scale)
	await _serve_human("mara", 1)
	await _serve_human("ben", 0)
	_mark("opening sales done")
	await _chores_while_waiting_for_leon()
	await _serve_human("leon1", 0)
	await _chores_until_leon_returns()
	await _serve_human("leon2", 0)
	_mark("leon second visit done")
	await _investigate_back()
	await _security()
	_mark("M4 complete")
	await _climax()
	await _shot("timed_end")
	_report()
	await world.finish_run(1 if failures else 0)

# --- customers ---------------------------------------------------------------------------------

func _serve_human(id: String, choice: int) -> void:
	var ok := await wait_until(func(): return game.checkout.state == Checkout.State.OPEN and game.checkout.customer != null and game.checkout.customer.profile.id == id and game.checkout.items.size() == game.checkout.customer.profile.items.size(), 150)
	var who: Node = game.checkout.customer
	check(ok, "%s reaches the counter (state=%d customer=%s)" % [id, game.checkout.state, str(who)] + _customer_debug())
	if not ok:
		return
	_mark("%s at counter" % id)
	var customer: Customer = game.checkout.customer
	await _walk_to(CLERK)
	await _think(0.8)
	await aim(CLERK, customer.global_position + Vector3(0, 1.0, 0))
	game.interactor.interact()
	await _think(1.4)  # read the reply options
	if game.dialogue.current_choices.size() > choice:
		game.dialogue.choose(choice)
	await wait_until(func(): return not game.dialogue.is_active(), 12)
	for item in game.checkout.items.duplicate():
		await aim(Vector3(item.global_position.x + 0.1, 0.05, 5.0), item.global_position + Vector3(0, 0.06, 0))
		await _think(0.6)
		game.interactor.interact()
	await aim(Vector3(-5.8, 0.05, 5.0), game.checkout.terminal.global_position)
	await _think(0.5)
	var sales := game.checkout.history.size()
	var tries := 0
	while game.checkout.history.size() == sales and tries < 5:
		game.interactor.interact()
		tries += 1
		await _think(0.7)
	check(game.checkout.history.size() == sales + 1, "%s: sale completed" % id)
	_mark("%s paid" % id)
	await wait_until(func(): return not is_instance_valid(customer) or customer.phase >= Customer.Phase.LEAVE, 20)
	await _think(0.5)

# --- chores ------------------------------------------------------------------------------------

func _customer_waiting() -> bool:
	return game.checkout.state == Checkout.State.OPEN and game.checkout.customer != null

func _chore_steps() -> Array:
	return [
		func(): await _do_latch_human(),
		func(): await _do_trash_human(),
		func(): await _do_restock_human()]

func _chores_while_waiting_for_leon() -> void:
	await _read_phone()
	for step in _chore_steps():
		if _customer_waiting():
			break
		await step.call()
	_mark("chores pass before leon1")

func _chores_until_leon_returns() -> void:
	for step in _chore_steps():
		if game.director.step == StoryDirector.Step.LEON_2:
			break
		await step.call()
	await _walk_to(CLERK)
	_mark("back at counter")

func _do_latch_human() -> void:
	if game.tasks.is_complete("latch"):
		return
	await _look_press(Vector3(4.25, 0.05, -4.9), ShiftTasks.LATCH_POINT)
	await _look_press(Vector3(4.25, 0.05, -4.9), ShiftTasks.LATCH_POINT + Vector3(0, -0.13, 0), 0.4)
	_mark("latch checked")

func _do_trash_human() -> void:
	if game.tasks.is_complete("trash"):
		return
	await _look_press(Vector3(-7.7, 0.05, 5.3), ShiftTasks.BIN_POINT + Vector3(0, 0.4, 0))
	await _walk_to(Vector3(4.25, 0.05, -4.2))
	await aim(Vector3(4.25, 0.05, -4.2), ShiftTasks.BAG_SPOT + Vector3(0, 0.08, 0))
	await _think(0.5)
	game.interactor.interact()
	_mark("trash out")

func _do_restock_human() -> void:
	if game.tasks.is_complete("restock"):
		return
	for i in 3:
		await _look_press(Vector3(5.75, 0.05, 0.3), ShiftTasks.CARTON_POINT + Vector3(0, 0.15, 0), 0.4)
		var slot: ShiftTasks.RestockSlot = game.shift.slots[i]
		await _look_press(Vector3(slot.position.x, 0.05, 3.4), slot.position + Vector3(0, 0.2, 0), 0.4)
	_mark("shelves stocked")

# --- the anomaly -------------------------------------------------------------------------------

func _investigate_back() -> void:
	var d := game.director
	await wait_until(func(): return d.step >= StoryDirector.Step.ANOMALY, 60)
	_mark("anomaly begins")
	await _read_phone()
	await _look_press(Vector3(6.2, 0.05, -3.1), Vector3(5.25, 1.45, -3.1), 1.0)
	await _look_press(Vector3(7.7, 0.05, -4.2), Clues.ENVELOPE_MOVED + Vector3(0, 0.05, 0), 1.0)
	await _look_press(Vector3(4.3, 0.05, -2.2), Vector3(4.3, 0.05, -3.5), 1.0)
	_mark("three clues found")
	await _shot("timed_clues")

# --- M4 ----------------------------------------------------------------------------------------

func _sit_at_desk() -> void:
	var sec := game.security
	await _walk_to(Vector3(7.4, 0.05, -4.3))
	await aim(Vector3(7.4, 0.05, -4.3), Vector3(7.7, 0.95, -5.2))
	await wait_until(func(): return sec.cctv.is_live(), 10)
	await _think(0.5)
	game.interactor.interact()
	await _think(0.8)
	sec.cctv.settle()
	check(sec.cctv.viewing, "the player sits at the desk (prompt='%s' live=%s focus=%s ppos=%s intruder=%s)" % [game.interactor.current_prompt().text, sec.cctv.is_live(), str(game.interactor.focus.get_path()) if game.interactor.focus else "none", player.global_position, str(sec.intruder.global_position) if is_instance_valid(sec.intruder) else "none"])

func _security() -> void:
	var d := game.director
	var sec := game.security
	await wait_until(func(): return d.step >= StoryDirector.Step.CAMERAS, 60)
	_mark("dina asks for the cameras")
	await _read_phone()
	await _sit_at_desk()
	_mark("at the cctv desk")
	await _think(2.5)
	await _shot("timed_cam1")
	sec.cctv.select(1)
	await _think(2.5)
	await _shot("timed_cam2")
	sec.cctv.leave()
	sec.cctv.settle()
	await wait_until(func(): return d.step >= StoryDirector.Step.BLACKOUT, 30)
	_mark("blackout")
	await _shot("timed_blackout")
	await _read_phone()
	await _walk_to(Vector3(4.25, 0.05, 3.0))
	await aim(Vector3(4.25, 0.05, 3.0), Vector3(4.78, 1.52, 2.81))
	await _think(0.8)
	game.interactor.interact()
	await wait_until(func(): return sec.breaker.cover.is_fully_open(), 3)
	await aim(Vector3(4.2, 0.0, 2.8), sec.breaker.levers["main"].global_position)
	await _think(0.6)
	game.interactor.interact()
	await aim(Vector3(4.2, 0.0, 2.8), sec.breaker.levers["security"].global_position)
	await _think(0.6)
	game.interactor.interact()
	await wait_until(func(): return d.step >= StoryDirector.Step.POWER_BACK, 10)
	_mark("power restored")
	await _read_phone()
	await _sit_at_desk()
	sec.cctv.select(1)
	_mark("watching rear camera viewing=%s live=%s prompt=%s focus=%s enabled=%s" % [sec.cctv.viewing, sec.cctv.is_live(), game.interactor.current_prompt().text, game.interactor.focus, game.interactor.enabled])
	await wait_until(func(): return d.step >= StoryDirector.Step.SECURITY_DONE, 90)
	await _think(2.0)
	await _shot("timed_signal_lost")
	sec.cctv.leave()
	sec.cctv.settle()
	await wait_until(func(): return game.phone.has_delivered("dina_8"), 10)
	await _read_phone()

# --- M5 ----------------------------------------------------------------------------------------

func _climax() -> void:
	var threat := game.director.threat
	await wait_until(func(): return threat.active, 10)
	_mark("climax begins (Leon is loose)")
	var ended := false
	match ending_plan:
		"escape":
			ended = await _run_escape()
		"caught", "caught_then_secured":
			await _stand_and_wait_to_be_caught()
			if ending_plan == "caught_then_secured":
				_mark("retry from checkpoint")
				game.flow.press("retry")
				await _think(1.0)
				await _secure_office()
		_:
			await _secure_office()
	await wait_until(func(): return threat.ended != "", 120)
	_mark("ending: %s (player %s, leon %s state %s)" % [threat.ended, player.global_position, str(threat.stalker.global_position) if is_instance_valid(threat.stalker) else "-", str(threat.stalker.state) if is_instance_valid(threat.stalker) else "-"])
	check(threat.ended != "", "the night reaches an ending")
	await _shot("timed_ending_" + threat.ended)

func _secure_office() -> void:
	var sec := game.security
	sec.cctv.leave()
	sec.cctv.settle()
	await _walk_to(Vector3(6.0, 0.05, -4.5))
	await aim(Vector3(6.0, 0.05, -4.5), _bolt_of(sec.office_door).global_position)
	await _think(0.6)
	game.interactor.interact()
	_mark("office locked in")
	await _walk_to(Vector3(6.9, 0.05, -4.4))
	await aim(Vector3(6.9, 0.05, -4.4), sec.landline.global_position)
	await _think(0.6)
	game.interactor.interact()
	_mark("calling the police")
	await wait_until(func(): return sec.landline.called, 40)
	_mark("call finished")

func _bolt_of(door: Door) -> Node:
	return door.leaves[0].body.get_children().filter(func(c): return c is Door.DoorBolt)[0]

func _run_escape() -> bool:
	var sec := game.security
	# A player would watch CAM 1 and go when he has walked off toward the west aisles; the bot just reads his position.
	var leon := game.director.threat.stalker
	leon.state_changed.connect(func(st): _mark("leon state %d at %s, player %s" % [st, leon.global_position, player.global_position]))
	await wait_until(func(): return is_instance_valid(leon) and leon.global_position.x < -1.0, 90)
	_mark("leon is in the west aisles, going")
	sec.cctv.leave()
	sec.cctv.settle()
	for waypoint in [Vector3(5.9, 0.05, -4.3), Vector3(4.25, 0.05, -4.3), Vector3(2.4, 0.05, -3.5), Vector3(2.4, 0.05, 2.9), Vector3(1.9, 0.05, 4.9)]:
		# Walking is quiet and running is heard through walls, so walk until he turns on you, then run.
		var steps := maxi(1, int(player.global_position.distance_to(waypoint) / 1.5))
		var start := player.global_position
		for i in range(1, steps + 1):
			var chasing: bool = is_instance_valid(leon) and leon.state == Stalker.State.CHASE
			await _walk_to(start.lerp(waypoint, float(i) / steps), 2.8 if chasing else 1.9)
			if game.director.threat.ended != "":
				return true
	await aim(Vector3(1.9, 0.05, 4.9), sec.front_door.leaves[0].body.global_position)
	game.interactor.interact()
	await _walk_to(Vector3(1.7, 0.05, 7.8), 2.8)
	return true

func _stand_and_wait_to_be_caught() -> void:
	game.security.cctv.leave()
	game.security.cctv.settle()
	await _walk_to(Vector3(-1.5, 0.05, 5.2))
	player.enabled = false
	await wait_until(func(): return game.director.threat.ended == "caught", 150)

func _report() -> void:
	print("---- TIMED PLAYTHROUGH (scripted bot, pace x%.1f; not a human playtest) ----" % pace_scale)
	var named := {
		"opening sales done": "opening (Mara + Ben)",
		"leon second visit done": "Leon visits + chores",
		"three clues found": "anomaly + clues",
		"blackout": "M4 cameras",
		"power restored": "M4 outage + breaker",
		"M4 complete": "M4 rear camera",
		"climax begins (Leon is loose)": "M4 -> climax handoff"}
	var prev := 0.0
	for m in marks:
		if named.has(m.label):
			print("SEGMENT %-24s ends %6.1fs  (+%5.1fs)" % [named[m.label], m.at, m.at - prev])
			prev = m.at
	print("FRAMES %d, wall %.1fs, avg fps %.1f, worst frame %.0f ms" % [frames, (Time.get_ticks_msec() - t0) / 1000.0, frames / maxf((Time.get_ticks_msec() - t0) / 1000.0, 0.1), worst_frame * 1000.0])
	print("TIMED TOTAL %.1fs = %.1f min through M4" % [_seconds(), _seconds() / 60.0])
	print("TIMED PLAYTHROUGH COMPLETE failures=", failures)

func _customer_debug() -> String:
	for c in get_tree().get_nodes_in_group("customers"):
		return " phase=%d pos=%s items=%d" % [c.phase, str(c.global_position), game.checkout.items.size()]
	return " no customers"
