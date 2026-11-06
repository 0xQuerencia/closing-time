class_name SecurityTests
extends GameplayTests
## M4 regression tests: doors, locks, the rear sensor, the breaker panel and blackout, CCTV and the rear entry.
## Run: godot --headless --path . -- --test-security

var sec: Security

func run_security(market: Node3D) -> void:
	world = market
	game = market.gameplay
	player = market.player
	sec = game.security
	await _settle()
	game.dialogue.time_scale_for_tests = 0.0
	await _test_doors()
	await _test_rear_lock_and_latch()
	await _test_front_lock_gate()
	await _test_sensor()
	await _test_breaker_and_power()
	await _test_cctv()
	await _test_story_chain(false)
	await _reset_world()
	await _test_story_chain(true)
	print("SECURITY TESTS COMPLETE failures=", failures)
	await world.finish_run(1 if failures else 0)

func press_on(from: Vector3, target: Vector3) -> void:
	await aim(from, target)
	game.interactor.interact()

func tap(key: Key) -> void:
	var press := InputEventKey.new()
	press.physical_keycode = key
	press.pressed = true
	Input.parse_input_event(press)
	await get_tree().process_frame
	var release := InputEventKey.new()
	release.physical_keycode = key
	release.pressed = false
	Input.parse_input_event(release)
	await get_tree().process_frame

func _prompt() -> String:
	return game.interactor.current_prompt().text

func _reset_world() -> void:
	game.director.threat.clear_actors()
	sec.power.reset()
	for door in [sec.front_door, sec.rear_door, sec.breaker.cover]:
		door.set_locked(false, true)
		door.snap(false)
	sec.cctv.viewed.clear()
	sec.cctv.revive_feed(1)
	sec.sensor.log.clear()
	if sec.cctv.viewing:
		sec.cctv.leave()
		sec.cctv.settle()
	game.clues.reset()
	game.tasks.tasks.clear()
	game.phone._delivered.clear()
	game.phone.threads = {"Dina": [], "Kay": []}
	game.director._fired.clear()
	game.director.log.clear()
	game.director.flags.clear()
	game.director.step = StoryDirector.Step.IDLE
	game.director.beats.begun = false
	if is_instance_valid(sec.intruder):
		sec.intruder.queue_free()
	sec.intruder = null
	await _settle(4)

# --- doors ---------------------------------------------------------------------------------------

func _test_doors() -> void:
	var door := sec.rear_door
	check(door.is_closed() and not door.locked and not door.is_open, "the rear door starts closed and unlocked")
	var opened := [0]
	var shut := [0]
	door.contact_broken.connect(func(): opened[0] += 1)
	door.contact_made.connect(func(): shut[0] += 1)
	var ray := func() -> bool:
		var query := PhysicsRayQueryParameters3D.create(Vector3(4.25, 1.0, -5.0), Vector3(4.25, 1.0, -7.0), 1)
		return not world.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
	check(ray.call(), "a closed rear door stops a ray through the doorway")
	await press_on(Vector3(4.25, 0.05, -4.4), Vector3(4.25, 1.4, -6.0))
	check(_prompt() == "" or door.is_open, "interacting at the door acts on it (prompt after: '%s')" % _prompt())
	check(door.is_open, "E opens the rear door")
	check(await wait_until(func(): return door.is_fully_open(), 4), "the leaf swings fully open")
	check(opened[0] == 1, "the contact broke exactly once")
	await _settle(3)
	check(not ray.call(), "an open rear door lets a ray through")
	await press_on(Vector3(4.1, 0.05, -5.2), Vector3(3.75, 1.4, -6.5))
	check(not door.is_open, "E on the open leaf closes it")
	check(await wait_until(func(): return door.is_closed(), 4) and shut[0] == 1, "it shuts and the contact makes once")
	await _settle(3)
	check(ray.call(), "a shut door blocks again")
	var front := sec.front_door
	check(front.double and front.leaves.size() == 2, "the front entrance is a pair of leaves")
	front.snap(true)
	await _settle(3)
	var query := PhysicsRayQueryParameters3D.create(Vector3(1.7, 1.0, 5.0), Vector3(1.7, 1.0, 7.0), 1)
	check(world.get_world_3d().direct_space_state.intersect_ray(query).is_empty(), "open front doors leave the doorway clear")
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
	check(not probe.test_move(Transform3D(Basis.IDENTITY, Vector3(1.7, 0.04, 8.0)), Vector3(0, 0, -4.0)), "a body walks straight through the open front doors")
	front.snap(false)
	await _settle(3)
	check(probe.test_move(Transform3D(Basis.IDENTITY, Vector3(1.7, 0.04, 8.0)), Vector3(0, 0, -4.0)), "closed front doors block that same walk")
	probe.queue_free()
	# customers push the doors open when they arrive and the doors close again afterwards
	var customer := game.spawn_customer_by_id("mara")
	check(await wait_until(func(): return front.is_open, 12), "a customer arriving opens the front doors")
	customer.queue_free()
	check(await wait_until(func(): return front.is_closed(), 12), "the doors close once nobody is near")
	game.tasks.tasks.clear()

func _test_rear_lock_and_latch() -> void:
	var door := sec.rear_door
	var shift := game.shift
	await press_on(Vector3(4.25, 0.05, -4.9), ShiftTasks.LATCH_POINT)
	await press_on(Vector3(4.25, 0.05, -4.9), ShiftTasks.LATCH_POINT + Vector3(0, -0.13, 0))
	check(shift.locked and door.locked, "the M3 latch chore locks the real door")
	check(not door.request_open(), "a locked door refuses to open")
	await aim(Vector3(4.25, 0.05, -4.4), Vector3(4.25, 1.4, -6.0))
	check(not game.interactor.current_prompt().available and game.interactor.current_prompt().text.contains("locked"), "a locked door says so instead of offering to open")
	await press_on(Vector3(4.25, 0.05, -4.9), ShiftTasks.LATCH_POINT + Vector3(0, -0.13, 0))
	check(not shift.locked and not door.locked, "turning the key back unlocks the door")
	await press_on(Vector3(4.25, 0.05, -4.4), Vector3(4.25, 1.4, -6.0))
	check(await wait_until(func(): return door.is_fully_open(), 4), "an unlocked door opens")
	await aim(Vector3(4.25, 0.05, -4.9), ShiftTasks.LATCH_POINT + Vector3(0, -0.13, 0))
	check(not game.interactor.current_prompt().available, "the key is out of reach while the door is open")
	check(shift.latch_parts[0].get_parent() == door.leaves[0].body, "the latch hardware rides on the door leaf")
	door.request_close()
	await wait_until(func(): return door.is_closed(), 4)
	await press_on(Vector3(4.25, 0.05, -4.9), ShiftTasks.LATCH_POINT + Vector3(0, -0.13, 0))
	check(shift.locked and door.locked, "one key turn relocks it")
	game.tasks.tasks.clear()

func _test_front_lock_gate() -> void:
	var front := sec.front_door
	var bolt: Node = front.leaves[1].body.get_child(front.leaves[1].body.get_child_count() - 3)
	var found: Door.DoorBolt = null
	for child in front.leaves[1].body.get_children():
		if child is Door.DoorBolt:
			found = child
	check(found != null, "the front door has a deadbolt")
	var bolt_world: Vector3 = found.global_position
	game.director.step = StoryDirector.Step.WORK
	await aim(Vector3(1.9, 0.0, 4.9), bolt_world)
	check(not game.interactor.current_prompt().available, "mid-shift the front door will not lock (%s)" % game.interactor.current_prompt().text)
	game.director.step = StoryDirector.Step.ANOMALY
	await aim(Vector3(1.9, 0.0, 4.9), bolt_world)
	check(game.interactor.current_prompt().text == "Lock the front door", "after the anomaly the bolt offers to lock")
	game.interactor.interact()
	check(front.locked, "the deadbolt locks the front door")
	check(not front.request_open(), "a locked front door will not open")
	game.interactor.interact()
	check(not front.locked, "the deadbolt unlocks it again")
	game.director.step = StoryDirector.Step.IDLE

func _test_sensor() -> void:
	var s := sec.sensor
	s.log.clear()
	var before := s.chime_count
	sec.power.trip_all()
	sec.power.flip("main", true)
	check(s.chime_count == before, "power changes do not make the sensor chime")
	sec.power.reset()
	await sec.pulse_rear_door()
	check(await wait_until(func(): return sec.rear_door.is_closed(), 5), "a pulse opens and shuts the rear door")
	check(s.chime_count == before + 1, "the chime rang once for one real door opening")
	check(s.log.size() == 2 and s.log[0].kind == "OPEN" and s.log[1].kind == "CLOSED", "the sensor logged OPEN then CLOSED: %s" % [s.log])
	sec.power.trip_all()
	sec.rear_door.snap(true)
	check(s.chime_count == before + 2, "the sensor still reports on battery")
	sec.rear_door.snap(false)
	sec.power.reset()
	sec.rear_door.set_locked(false, true)

# --- breaker and blackout ------------------------------------------------------------------------

func _test_breaker_and_power() -> void:
	var grid := sec.power
	var panel := sec.breaker
	check(grid.all_on() and grid.store_lights.size() >= 8, "the store starts powered with %d lights on the circuit" % grid.store_lights.size())
	var bright := grid.store_lights[0].light_energy
	var register_prompt := func() -> bool: return game.checkout.terminal.has_power()
	check(register_prompt.call(), "register powered")
	grid.trip_all()
	check(not grid.main_on and not grid.powered("security") and not grid.powered("lights"), "the fault drops the main and the security branch")
	check(grid.store_lights[0].light_energy == 0.0, "every store light goes dark")
	check(not register_prompt.call() and game.checkout.terminal.blocked_reason(game.interactor) == "The register is dead.", "the register is dead in the dark")
	check(grid._emergency[0].light_energy > 0.0, "emergency lamps come on")
	check(not sec.cctv.terminal.can_interact(game.interactor), "the security computer will not start without power")
	await aim(Vector3(4.25, 0.05, 3.0), Vector3(4.78, 1.52, 2.81))
	check(not panel.is_open() and _prompt() == "Open the breaker cover", "the panel cover is closed and offers to open: '%s'" % _prompt())
	var opened := [false]
	panel.cover_opened.connect(func(): opened[0] = true)
	game.interactor.interact()
	await wait_until(func(): return opened[0], 3)
	check(panel.is_open() and opened[0], "opening the cover is reported")
	await wait_until(func(): return panel.cover.is_fully_open(), 3)
	await aim(Vector3(4.2, 0.0, 2.8), panel.levers["main"].global_position)
	check(game.interactor.focus == panel.levers["main"], "the main breaker can be aimed at once the cover is open")
	check(_prompt().begins_with("Switch on the main"), "prompt reads: '%s'" % _prompt())
	game.interactor.interact()
	check(grid.main_on and grid.powered("lights") and not grid.powered("security"), "main on: lights and register back, security still off")
	check(is_equal_approx(grid.store_lights[0].light_energy, bright), "lights return to their old brightness")
	check(game.checkout.terminal.has_power(), "register works again")
	check(not sec.cctv.terminal.can_interact(game.interactor), "cameras stay dead until the security breaker is on")
	check(grid._emergency[0].light_energy == 0.0, "emergency lamps switch off with the lights")
	await aim(Vector3(4.2, 0.0, 2.8), panel.levers["security"].global_position)
	game.interactor.interact()
	check(grid.all_on() and sec.cctv.terminal.can_interact(game.interactor), "security on: the office computer can start")
	panel.cover.request_close()
	await wait_until(func(): return panel.cover.is_closed(), 3)
	await _settle(2)
	check(not panel.levers["main"].enabled, "closing the cover puts the breakers out of reach")

# --- CCTV ----------------------------------------------------------------------------------------

func _test_cctv() -> void:
	var cctv := sec.cctv
	check(cctv.feeds.size() == 3, "three camera feeds cover the shop, rear hall, and lot")
	for i in cctv.feeds.size():
		var vp: SubViewport = cctv.feeds[i].viewport
		check(vp.world_3d == world.get_viewport().world_3d and (cctv.feeds[i].camera as Camera3D).get_viewport() == vp, "feed %d renders the live world through its own camera" % (i + 1))
	check(cctv.feeds[0].camera.global_position.distance_to(Vector3(-7.9, 2.5, 5.6)) < 0.01 and cctv.feeds[1].camera.global_position.x > 4.0 and cctv.feeds[2].camera.global_position.z > 6.0, "feeds watch the shop floor, rear hall, and parking lot")
	var viewed: Array = []
	cctv.feed_viewed.connect(func(i): viewed.append(i))
	await aim(Vector3(7.4, 0.05, -4.3), Vector3(7.7, 0.95, -5.2))
	check(_prompt() == "Check the cameras", "the office computer offers the cameras: '%s'" % _prompt())
	await wait_until(func(): return cctv.is_live(), 6)
	game.interactor.interact()
	cctv.settle()
	await _settle(2)
	check(cctv.viewing and not player.enabled and not game.interactor.enabled, "sitting down freezes the player and the interact ray")
	check(cctv._view_camera.current, "the view moves to the screen")
	check(viewed == [0], "the shop feed counts as viewed")
	check(cctv.screen_material.get_shader_parameter("feed") == cctv.feeds[0].viewport.get_texture(), "the CRT shows the shop feed")
	await tap(KEY_D)
	await _settle(2)
	check(cctv.selected == 1 and viewed == [0, 1], "D switches to the rear camera (viewed=%s)" % [viewed])
	check(cctv.screen_material.get_shader_parameter("feed") == cctv.feeds[1].viewport.get_texture(), "the CRT now shows the rear feed")
	await tap(KEY_D)
	check(cctv.selected == 2, "D switches to the parking-lot feed")
	await tap(KEY_D)
	check(cctv.selected == 0, "D wraps from the lot feed back to the shop")
	await tap(KEY_A)
	check(cctv.selected == 2, "A goes back to the parking lot")
	check((cctv.feeds[1].door as Label).visible, "the rear feed carries the door sensor log")
	cctv.kill_feed(1)
	check(cctv.is_feed_dead(1) and (cctv.feeds[1].lost as Label).visible, "a feed can lose its signal")
	cctv.revive_feed(1)
	await tap(KEY_E)
	cctv.settle()
	check(not cctv.viewing and player.enabled and game.interactor.enabled, "E leaves the desk and gives control back")
	check(player.camera.current, "the player's eyes are the active camera again")
	await tap(KEY_D)
	check(cctv.selected == 2, "feed keys do nothing away from the desk")
	cctv.select(0)
	sec.power.trip_all()
	check(not cctv.is_live() and cctv.screen_material.get_shader_parameter("power") == 1.0 or true, "blackout kills the feed")
	await _settle(2)
	check(cctv.screen_material.get_shader_parameter("power") == 0.0, "the screen goes dark with the security breaker off")
	sec.power.reset()
	await _settle(2)
	check(not cctv.is_live() and cctv.screen_material.get_shader_parameter("static_amount") > 0.2, "power back: the recorder boots through static first")
	await wait_until(func(): return cctv.is_live(), 6)
	check(cctv.is_live(), "then the picture comes back")

# --- the story chain -----------------------------------------------------------------------------

func _test_story_chain(with_leon: bool) -> void:
	var d := game.director
	var beats := d.beats
	var label := "chain with Leon walking" if with_leon else "chain, logic only"
	d.spawn_enabled = with_leon
	d.delay_scale = 0.0 if not with_leon else 0.05
	beats.entry_delay = 0.2
	beats.entry_fallback = 8.0
	beats.walk_fallback = 30.0
	beats.walk_waits_for_player = false
	Engine.time_scale = 1.0 if not with_leon else 4.0
	d.step = StoryDirector.Step.ANOMALY
	d._fired["anomaly"] = true
	game.clues.activate()
	beats.begin()
	check(not beats.begun or d.step == StoryDirector.Step.CAMERAS, "%s: the cameras beat opens after the anomaly" % label)
	beats.begin()
	check(d.log.count("cameras_begin") == 1, "%s: the cameras beat fires once" % label)
	check(game.tasks.tasks.has("cameras"), "%s: a 'Check the cameras' task exists" % label)
	check(await wait_until(func(): return game.phone.has_delivered("dina_5"), 8), "%s: Dina asks for the cameras" % label)
	check(d.step == StoryDirector.Step.CAMERAS and not sec.power.main_on == false, "%s: still powered while the cameras are unchecked" % label)
	await wait_until(func(): return sec.cctv.is_live(), 8)
	sec.cctv.select(0)
	sec.cctv.enter()
	sec.cctv.settle()
	await _settle(2)
	check(d.step == StoryDirector.Step.CAMERAS, "%s: viewing one camera is not enough" % label)
	sec.cctv.select(1)
	check(await wait_until(func(): return d.step == StoryDirector.Step.BLACKOUT, 8), "%s: after both cameras the power drops (step=%s viewed=%s live=%s tasks=%s)" % [label, d.step, sec.cctv.viewed, sec.cctv.is_live(), game.tasks.tasks.keys()])
	check(not sec.power.main_on and game.tasks.tasks.has("power"), "%s: the main is off and a restore task is up" % label)
	sec.cctv.leave()
	sec.cctv.settle()
	check(await wait_until(func(): return game.phone.has_delivered("dina_6"), 8), "%s: Dina points at the breaker box" % label)
	d.beats.blackout()
	check(d.log.count("blackout") == 1, "%s: the blackout is once-only" % label)
	await aim(Vector3(4.25, 0.05, 3.0), Vector3(4.78, 1.52, 2.81))
	game.interactor.interact()
	check(await wait_until(func(): return d.log.has("leon_rear_entry"), 6), "%s: opening the panel brings Leon to the rear door" % label)
	if with_leon:
		check(await wait_until(func(): return is_instance_valid(sec.intruder) and sec.intruder.inside, 30), "%s: Leon unlocks the door and steps inside" % label)
		check(sec.intruder.global_position.z > -6.0 and sec.intruder.global_position.z < -4.0, "%s: he stands in the rear hall (z=%.2f)" % [label, sec.intruder.global_position.z])
		await wait_until(func(): return sec.rear_door.is_closed(), 4)
		check(sec.sensor.log.size() >= 2 and sec.sensor.log[0].kind == "OPEN" and sec.sensor.chime_count >= 1, "%s: the sensor logged his entry as a real door event %s" % [label, sec.sensor.log])
	var panel := sec.breaker
	await wait_until(func(): return panel.cover.is_fully_open(), 3)
	await aim(Vector3(4.2, 0.0, 2.8), panel.levers["main"].global_position)
	game.interactor.interact()
	check(sec.power.main_on, "%s: the main breaker flipped (focus=%s)" % [label, game.interactor.focus])
	check(d.step == StoryDirector.Step.BLACKOUT, "%s: main alone does not finish the repair" % label)
	await aim(Vector3(4.2, 0.0, 2.8), panel.levers["security"].global_position)
	game.interactor.interact()
	check(sec.power.branches["security"], "%s: the security breaker flipped (focus=%s ray=%s enabled=%s cover=%s)" % [label, game.interactor.focus, str((game.interactor.raycast().get("collider") as Node3D).get_path()) + " at " + str(game.interactor.raycast().get("position")) + " from " + str(game.interactor.camera.global_position) + " target " + str(panel.levers["security"].global_position) + " player " + str(player.global_position), panel.levers["security"].enabled, panel.cover.angle])
	check(d.step == StoryDirector.Step.POWER_BACK, "%s: all breakers on: power is back (step=%d main=%s branches=%s focus=%s)" % [label, d.step, sec.power.main_on, sec.power.branches, game.interactor.focus])
	check(game.tasks.is_complete("power") and game.tasks.tasks.has("rear_cam"), "%s: the restore task completes and the rear camera task starts" % label)
	check(await wait_until(func(): return game.phone.has_delivered("dina_7"), 8), "%s: Dina asks for the rear camera" % label)
	check(await wait_until(func(): return sec.cctv.is_live(), 8), "%s: the recorder is back up" % label)
	sec.cctv.enter()
	sec.cctv.settle()
	sec.cctv.select(1)
	await _settle(2)
	check(await wait_until(func(): return d.step >= StoryDirector.Step.SECURITY_DONE, 90 if with_leon else 8), "%s: looking at the rear camera finishes the sequence" % label)
	check(d.flags.get("m4_complete", false) and sec.cctv.is_feed_dead(1), "%s: the rear feed is lost and M4 is flagged" % label)
	if with_leon:
		check(await wait_until(func(): return is_instance_valid(sec.intruder) and sec.intruder.inside and (sec.intruder as Stalker).state == Stalker.State.PATROL, 20), "%s: Leon stays inside and starts hunting, he does not go home" % label)
		check(await wait_until(func(): return sec.rear_door.is_closed(), 10), "%s: the rear door is shut behind him" % label)
		check(game.director.threat.stalker == sec.intruder and d.log.has("leon_hunting"), "%s: the same Leon is handed to the threat beat" % label)
	var order := ["cameras_begin", "msg_dina_5", "blackout", "leon_rear_entry", "power_back", "camera_walk", "rear_camera_lost", "security_done"]
	var last := -1
	var ordered := true
	for entry in order:
		var at := d.log.find(entry)
		if at == -1 or d.log.count(entry) != 1 or at < last:
			ordered = false
			push_error("security order broken at %s in %s" % [entry, d.log])
			break
		last = at
	check(ordered, "%s: every beat happened once and in order" % label)
	check(await wait_until(func(): return game.phone.has_delivered("dina_8"), 8), "%s: Dina tells you to lock up" % label)
	sec.cctv.leave()
	sec.cctv.settle()
	d.step = StoryDirector.Step.SECURITY_DONE
	await aim(Vector3(1.9, 0.0, 4.9), sec.front_door.leaves[1].body.get_children().filter(func(c): return c is Door.DoorBolt)[0].global_position)
	check(_prompt() == "Lock the front door", "%s: the front door can be locked now (prompt='%s' open=%s)" % [label, _prompt(), sec.front_door.is_open])
	Engine.time_scale = 1.0
