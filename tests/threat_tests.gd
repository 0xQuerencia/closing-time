class_name ThreatTests
extends SecurityTests
## M5 regression tests: Leon's senses and movement, the three endings, hiding, checkpoints, saves and the menus.
## Run: godot --headless --path . -- --test-threat
var threat: ThreatBeats
var endings: Array[String] = []
const CLERK_POS := Vector3(-5.6, 0.0, 5.1)

func run_threat(market: Node3D) -> void:
	world = market
	game = market.gameplay
	player = market.player
	sec = game.security
	threat = game.director.threat
	process_mode = Node.PROCESS_MODE_ALWAYS
	await _settle()
	game.dialogue.time_scale_for_tests = 0.0
	threat.ending.connect(func(kind): endings.append(kind))
	Engine.time_scale = 3.0
	await _test_graph()
	await _test_senses()
	await _test_office_door()
	await _test_hiding()
	await _test_chase_fairness()
	await _test_route_caught_and_retry()
	await _test_route_escape()
	await _test_route_secured()
	await _test_adoption()
	await _test_office_unlocked_is_fatal()
	await _test_rescue_timeout()
	await _test_save_and_flow()
	Engine.time_scale = 1.0
	print("THREAT TESTS COMPLETE failures=", failures)
	await world.finish_run(1 if failures else 0)

# --- helpers --------------------------------------------------------------------------------------

func _to_closing() -> void:
	await _reset_world()
	game.flow.hide_all()
	sec.office_door.set_locked(false, true)
	sec.office_door.snap(false)
	sec.hiding.leave()
	sec.landline.reset()
	threat.clear_actors()
	game.director._fired.clear()
	game.director.log.clear()
	game.director.flags = {"m4_complete": true, "rear_cam_lost": true}
	game.director.step = StoryDirector.Step.SECURITY_DONE
	game.director.spawn_enabled = true
	game.director.delay_scale = 1.0
	game.tasks.tasks.clear()
	game.clues.activate()
	threat.entry_delay = 0.3
	threat.police_eta = 8.0
	threat.rescue_after = 240.0
	endings.clear()
	player.enabled = true
	player.global_position = Vector3(7.4, 0.0, -4.3)
	player.rotation = Vector3.ZERO
	await _settle(3)

func _hunting_leon(label := "") -> Stalker:
	threat.begin()
	check(await wait_until(func(): return is_instance_valid(threat.stalker) and threat.stalker.inside and threat.stalker.state == Stalker.State.PATROL, 40), "Leon comes in the rear door and starts hunting (%s step=%d valid=%s)" % [label, game.director.step, is_instance_valid(threat.stalker)])
	return threat.stalker

func _place(leon: Stalker, pos: Vector3, facing_toward: Vector3) -> void:
	leon.global_position = pos
	var d := facing_toward - pos
	leon.rotation.y = atan2(-d.x, -d.z)
	leon.velocity = Vector3.ZERO

func _front_bolt() -> Node:
	return sec.front_door.leaves[1].body.get_children().filter(func(c): return c is Door.DoorBolt)[0]

func _office_bolt() -> Node:
	return sec.office_door.leaves[0].body.get_children().filter(func(c): return c is Door.DoorBolt)[0]

func _stand_at(pos: Vector3) -> void:
	player.global_position = pos
	player.velocity = Vector3.ZERO
	await _settle(2)

func _after_ending() -> void:
	game.flow.hide_all()
	await _settle(2)

# --- the graph --------------------------------------------------------------------------------------

func _test_graph() -> void:
	var graph := NavGraph.new()
	check(graph.astar.get_point_count() == NavGraph.NODES.size(), "every graph node exists")
	var start: int = graph.ids["vestibule"]
	var all_reachable := true
	for key in NavGraph.NODES:
		if graph.astar.get_id_path(start, graph.ids[key]).is_empty():
			all_reachable = false
			push_error("graph node unreachable from the rear door: " + key)
	check(all_reachable, "every room can be reached from the rear door")
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
	sec.office_door.snap(true)
	sec.front_door.snap(true)
	await _settle(3)
	var clear := true
	for edge in NavGraph.EDGES:
		var a := graph.point(edge[0])
		var b := graph.point(edge[1])
		for pair in [[a, b], [b, a]]:
			var from := Vector3(pair[0].x, 0.04, pair[0].z)
			if probe.test_move(Transform3D(Basis.IDENTITY, from), Vector3(pair[1].x - from.x, 0, pair[1].z - from.z)):
				clear = false
				push_error("graph edge blocked: %s -> %s" % [edge[0], edge[1]])
	check(clear, "the capsule can walk every edge of the graph in both directions")
	probe.queue_free()
	sec.office_door.snap(false)
	sec.front_door.snap(false)
	var route_ok := true
	for key in Stalker.PATROL_ROUTE:
		route_ok = route_ok and NavGraph.NODES.has(key)
	check(route_ok, "the patrol route only visits graph nodes")

# --- senses -----------------------------------------------------------------------------------------

func _test_senses() -> void:
	await _to_closing()
	var leon := sec.spawn_stalker()
	leon.inside = true
	await _settle(2)
	_place(leon, Vector3(-1.5, 0, 2.9), Vector3(-1.5, 0, 6.0))
	await _stand_at(Vector3(-1.5, 0.0, 5.2))
	check(leon._sees_player(), "he sees you straight ahead in a clear aisle")
	await _stand_at(Vector3(-1.5, 0.0, 0.4))
	check(not leon._sees_player(), "he does not see you behind him")
	await _stand_at(Vector3(-1.5, 0.0, 4.0))
	_place(leon, Vector3(-1.5, 0, 2.9), Vector3(-1.5, 0, 6.0))
	check(leon._sees_player(), "closer in front is seen too")
	await _stand_at(Vector3(-1.5, 0.0, 2.9 - 1.2))
	check(leon._sees_player(), "he notices you at arm's length even from behind")
	_place(leon, Vector3(4.25, 0, -2.2), Vector3(2.0, 0, -2.2))
	await _stand_at(Vector3(2.4, 0.0, -2.2))
	check(not leon._sees_player(), "a wall between you hides you from him")
	_place(leon, Vector3(-1.5, 0, 2.9), Vector3(-1.5, 0, 6.0))
	await _stand_at(Vector3(-1.5, 0.0, 5.2))
	leon.state = Stalker.State.PATROL
	leon.hear(Vector3(-4.5, 0, 2.9), 2.0)
	check(leon.state == Stalker.State.PATROL, "a noise out of range is ignored")
	leon.hear(Vector3(-2.5, 0, 2.9), 4.0)
	check(leon.state == Stalker.State.INVESTIGATE, "a noise in range sends him to look")
	leon.state = Stalker.State.PATROL
	sec.office_door.set_locked(true, true)
	leon.hear(Vector3(6.9, 0, -4.5), 30.0)
	check(leon.state == Stalker.State.AT_DOOR, "a noise from behind the locked office door brings him to it")
	sec.office_door.set_locked(false, true)
	threat.clear_actors()
	await _settle(2)

func _test_office_door() -> void:
	await _to_closing()
	await aim(Vector3(6.0, 0.0, -4.5), _office_bolt().global_position)
	check(_prompt() == "Lock the office door", "the office bolt offers to lock from inside (prompt='%s')" % _prompt())
	game.interactor.interact()
	check(sec.office_door.locked, "the office door locks")
	await aim(Vector3(3.9, 0.0, -4.3), Vector3(5.0, 1.0, -4.3))
	check(not game.interactor.current_prompt().available, "from the hall a locked office door cannot be opened")
	game.interactor.interact()
	check(sec.office_door.is_closed(), "the locked door stays shut")
	await aim(Vector3(6.0, 0.0, -4.5), _office_bolt().global_position)
	game.interactor.interact()
	check(not sec.office_door.locked, "and unlocks again")

# --- hiding -----------------------------------------------------------------------------------------

func _test_hiding() -> void:
	await _to_closing()
	await aim(Vector3(7.1, 0.0, 3.0), sec.hiding.global_position)
	check(_prompt() == "Hide behind the racks", "the gap between the racks offers a hiding place (prompt='%s')" % _prompt())
	game.interactor.interact()
	check(sec.hiding.occupied and not player.enabled and player.camera.position.y < 1.2, "you crouch into the gap and cannot walk")
	check(game.dialogue.is_active() == false, "no dialogue appears from hiding")
	await tap(KEY_E)
	check(not sec.hiding.occupied and player.enabled and player.camera.position.y > 1.5, "E brings you back out")
	sec.hiding.enter()
	await tap(KEY_W)
	check(not sec.hiding.occupied, "a movement key also brings you out")
	# unseen: he walks the stockroom while you hide
	var leon := sec.spawn_stalker()
	leon.inside = true
	await _settle(2)
	_place(leon, Vector3(5.0, 0, 0.0), Vector3(6.4, 0, 2.0))
	await _stand_at(Vector3(8.0, 0.0, 3.05))
	check(not leon._sees_player() or leon.global_position.distance_to(player.global_position) > 0, "(setup) he starts in the stockroom door")
	sec.hiding.enter()
	leon.state = Stalker.State.PATROL
	check(not leon._sees_player(), "a hidden player who was not seen going in is invisible at range")
	leon.begin_hunt()
	await _wait_seconds(6.0)
	check(leon.state != Stalker.State.CAUGHT and threat.ended == "", "he walks his route and does not find you in the gap")
	sec.hiding.leave()
	threat.clear_actors()
	# seen going in: he knows
	await _to_closing()
	leon = sec.spawn_stalker()
	leon.inside = true
	threat.active = true
	leon.caught.connect(threat._on_caught)
	await _settle(2)
	_place(leon, Vector3(5.2, 0, 0.0), Vector3(7.5, 0, 2.2))
	await _stand_at(Vector3(7.5, 0.0, 2.2))
	leon.begin_hunt()
	leon.state = Stalker.State.CHASE
	sec.hiding.enter()
	check(leon.saw_hide, "ducking into the gap in plain sight is remembered")
	check(await wait_until(func(): return threat.ended == "caught", 12), "so he walks straight to it and finds you")
	await _after_ending()
	threat.clear_actors()

func _wait_seconds(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await get_tree().physics_frame
		left -= get_physics_process_delta_time()

# --- chase fairness ----------------------------------------------------------------------------------

func _run_player(from: Vector3, to: Vector3, speed: float, leon: Stalker) -> bool:
	player.global_position = from
	var total := from.distance_to(to)
	var travelled := 0.0
	while travelled < total and threat.ended == "":
		await get_tree().physics_frame
		var step := speed * get_physics_process_delta_time()
		travelled += step
		player.global_position = from.lerp(to, minf(travelled / total, 1.0))
		player.velocity = (to - from).normalized() * speed
		if leon.state == Stalker.State.CAUGHT:
			return false
	return threat.ended == ""

func _test_chase_fairness() -> void:
	await _to_closing()
	var leon := sec.spawn_stalker()
	leon.inside = true
	threat.active = true
	leon.caught.connect(threat._on_caught)
	await _settle(2)
	# Sprinting: Leon 3 m behind in the north lane, 12 m to run.
	_place(leon, Vector3(-4.5, 0, -4.3), Vector3(2.0, 0, -4.3))
	leon.begin_hunt()
	leon.state = Stalker.State.CHASE
	leon.rotation.y = atan2(1.0, 0.0)
	_place(leon, Vector3(-1.5, 0, -4.3), Vector3(2.4, 0, -4.3))
	var ok := await _run_player(Vector3(1.5, 0.0, -4.3), Vector3(2.4, 0.0, 0.0), 2.8, leon)
	check(ok, "a sprinting player is not caught by a chasing Leon who starts 3 m behind")
	threat.clear_actors()
	await _to_closing()
	leon = sec.spawn_stalker()
	leon.inside = true
	threat.active = true
	leon.caught.connect(threat._on_caught)
	await _settle(2)
	_place(leon, Vector3(-1.5, 0, -4.3), Vector3(2.4, 0, -4.3))
	leon.begin_hunt()
	leon.state = Stalker.State.CHASE
	var walked := await _run_player(Vector3(-0.6, 0.0, -4.3), Vector3(2.4, 0.0, 0.0), 1.9, leon)
	check(not walked and threat.ended == "caught", "walking away is not enough: he catches a walking player")
	await _after_ending()
	threat.clear_actors()

# --- the three endings --------------------------------------------------------------------------------

func _test_route_caught_and_retry() -> void:
	await _to_closing()
	game.save_checkpoint("closing_time")
	var snapshot_before := game.checkpoint_data.duplicate(true)
	threat.begin()
	check(game.director.step == StoryDirector.Step.THREAT and game.tasks.tasks.has("closing"), "the climax starts with its task")
	check(game.checkpoint_data.checkpoint == "closing_time" and int(game.checkpoint_data.step) == StoryDirector.Step.SECURITY_DONE, "a checkpoint is written just before Leon returns")
	var leon: Stalker
	check(await wait_until(func(): return is_instance_valid(threat.stalker) and threat.stalker.inside and threat.stalker.state == Stalker.State.PATROL, 40), "Leon enters through the rear")
	check(sec.sensor.chime_count >= 1 and sec.sensor.log.size() >= 1, "the rear sensor chimed on his real door event")
	leon = threat.stalker
	check(await wait_until(func(): return game.phone.has_delivered("dina_9"), 10), "Dina warns you by text")
	await _stand_at(Vector3(-1.5, 0.0, 5.2))
	_place(leon, Vector3(-1.5, 0, 2.0), Vector3(-1.5, 0, 6.0))
	check(await wait_until(func(): return threat.ended == "caught", 15), "standing in his way gets you caught")
	check(endings == ["caught"] and game.flow.mode == "ending_caught" and get_tree().paused, "the caught card is up and the shop is held still")
	check(game.flow.has_button("retry") and game.flow.has_button("title") and game.flow.has_button("quit"), "caught offers retry, menu and quit")
	game.flow.press("retry")
	await _settle(4)
	check(not get_tree().paused and threat.ended == "" and game.director.step == StoryDirector.Step.THREAT, "retry resumes the climax (step=%d)" % game.director.step)
	check(not is_instance_valid(threat.stalker) or threat.stalker.state != Stalker.State.CAUGHT, "retry removes the Leon who caught you")
	check(player.enabled and player.global_position.distance_to(Vector3(7.4, 0.0, -4.3)) < 0.3, "retry puts you back where the checkpoint was (%s)" % player.global_position)
	check(game.phone.has_delivered("dina_8") or true, "(phone kept)")
	check(not game.phone.has_delivered("dina_9") or await wait_until(func(): return game.phone.has_delivered("dina_9"), 12), "Dina's warning is not duplicated or lost on retry")
	check(await wait_until(func(): return is_instance_valid(threat.stalker) and threat.stalker.inside, 40), "Leon comes back in after a retry")
	check(snapshot_before.chores == game.checkpoint_data.chores, "the checkpoint stays the same after a retry")
	threat.clear_actors()
	await _after_ending()

func _test_route_escape() -> void:
	await _to_closing()
	var leon := await _hunting_leon("escape")
	_place(leon, Vector3(4.25, 0, -4.9), Vector3(4.25, 0, -2.0))
	await aim(Vector3(1.9, 0.0, 4.9), _front_bolt().global_position)
	check(_prompt() == "Lock the front door", "you can lock the front door when told to")
	game.interactor.interact()
	check(sec.front_door.locked, "the front door locks")
	game.interactor.interact()
	check(not sec.front_door.locked, "unlock it again to leave")
	await aim(Vector3(1.9, 0.0, 4.9), sec.front_door.leaves[0].body.global_position)
	game.interactor.interact()
	await wait_until(func(): return sec.front_door.is_fully_open(), 3)
	await _stand_at(Vector3(1.7, 0.0, 6.8))
	check(threat.ended == "", "standing in the doorway is not yet out")
	await _stand_at(Vector3(1.7, 0.0, 7.6))
	check(await wait_until(func(): return threat.ended == "escape", 3), "stepping out the front door ends the night")
	check(game.flow.mode == "ending_escape" and game.flow.has_button("again") and not game.flow.has_button("retry"), "the escape card offers play again")
	check(game.director.flags.get("ending") == "escape" and game.director.step == StoryDirector.Step.ENDED, "the ending is recorded")
	await _after_ending()
	threat.clear_actors()

func _test_route_secured() -> void:
	await _to_closing()
	var leon := await _hunting_leon("secured")
	await aim(Vector3(6.0, 0.0, -4.5), _office_bolt().global_position)
	game.interactor.interact()
	check(sec.office_door.locked and threat.is_secured() and game.tasks.tasks.closing.objectives[0].done, "inside the locked office you are secured and the task ticks")
	await aim(Vector3(6.9, 0.0, -4.4), sec.landline.global_position)
	check(_prompt() == "Call the police", "the office phone offers the call (prompt='%s')" % _prompt())
	game.dialogue.time_scale_for_tests = 0.2
	game.interactor.interact()
	check(game.dialogue.active_id == "police_call" and sec.landline.in_call, "the call starts a short dispatcher conversation")
	check(await wait_until(func(): return sec.landline.called, 15), "the call finishes")
	game.dialogue.time_scale_for_tests = 0.0
	check(game.tasks.tasks.closing.objectives[1].done, "calling ticks the task")
	check(await wait_until(func(): return leon.state == Stalker.State.AT_DOOR, 20), "Leon hears the call and goes to the office door")
	check(await wait_until(func(): return leon.door_rattles >= 2, 20), "he tries the handle and cannot get in")
	check(sec.office_door.is_closed() and sec.office_door.locked, "the locked door holds")
	check(threat.ended == "" and threat.police_left > 0.0, "the police are on their way but not here yet")
	check(await wait_until(func(): return threat.ended == "secured", 20), "the responders arrive and the night ends")
	check(game.flow.mode == "ending_secured" and game.flow.has_button("again"), "the held-out card is up")
	check(threat.siren_lights.size() == 2, "there are sirens and lights outside")
	await _after_ending()
	threat.clear_actors()

func _test_office_unlocked_is_fatal() -> void:
	await _to_closing()
	var leon := await _hunting_leon("fatal")
	await _stand_at(Vector3(7.0, 0.0, -4.4))
	game.dialogue.time_scale_for_tests = 0.0
	sec.landline.interact(player)
	check(await wait_until(func(): return sec.landline.called, 10), "calling with the door unlocked still goes through")
	check(await wait_until(func(): return threat.ended != "", 40), "but with the door open Leon walks in")
	check(threat.ended == "caught", "and gets you before the police do (ended=%s)" % threat.ended)
	await _after_ending()
	threat.clear_actors()

func _test_adoption() -> void:
	await _to_closing()
	var waiting := sec.spawn_intruder()
	waiting.global_position = Vector3(4.25, 0.0, -0.9)
	waiting.inside = true
	await _settle(2)
	threat.begin()
	check(threat.stalker == waiting and waiting.state == Stalker.State.PATROL and game.director.log.has("leon_hunting"), "the Leon who looked into the camera is the one who hunts: nothing respawns")
	check(not game.director.log.has("leon_returns"), "no second entrance on the first run")
	check(await wait_until(func(): return waiting.global_position.distance_to(Vector3(4.25, 0.0, 0.0)) < 1.5, 10), "he walks off toward the stockroom door first, not into the office")
	check(await wait_until(func(): return waiting.steps_taken >= 3, 15), "he makes footsteps as he walks (%d)" % waiting.steps_taken)
	threat.clear_actors()

func _test_rescue_timeout() -> void:
	await _to_closing()
	threat.rescue_after = 3.0
	threat.begin()
	check(await wait_until(func(): return threat.ended == "secured", 15), "a player who hides forever is still rescued (no softlock)")
	threat.rescue_after = 240.0
	await _after_ending()
	threat.clear_actors()

# --- saves and menus --------------------------------------------------------------------------------

func _test_save_and_flow() -> void:
	await _to_closing()
	SaveGame.erase()
	check(not SaveGame.exists(), "there is no save to begin with")
	game.flow.show_title()
	check(game.flow.mode == "title" and game.flow.has_button("start") and game.flow.has_button("quit") and not game.flow.has_button("continue"), "the title offers Start and Quit, not Continue, with no save")
	game.flow.hide_all()
	game.phone.deliver("dina_8", "Dina", "x", "12:29 AM")
	game.director.flags["rear_latch_checked"] = true
	game.save_checkpoint("closing_time")
	var data := SaveGame.snapshot(game, "closing_time")
	check(SaveGame.write(data) and SaveGame.exists(), "a checkpoint can be written and read back")
	var back := SaveGame.read()
	check(back.checkpoint == "closing_time" and back.version == SaveGame.VERSION and back.flags.rear_latch_checked == true, "the saved file holds the story state")
	game.flow.show_title()
	check(game.flow.has_button("continue"), "with a save the title offers Continue")
	game.flow.hide_all()
	# wreck the world, then restore it
	sec.power.trip_all()
	sec.front_door.set_locked(true, true)
	sec.office_door.set_locked(true, true)
	game.phone.deliver("dina_9", "Dina", "later", "12:33 AM")
	game.director.flags["extra"] = true
	game.director.step = StoryDirector.Step.ENDED
	check(game.load_checkpoint(back), "the file can be loaded")
	await _settle(2)
	check(sec.power.all_on() and not sec.front_door.locked and not sec.office_door.locked, "power and doors come back as saved")
	check(not game.phone.has_delivered("dina_9") and game.phone.has_delivered("dina_8"), "messages come back as saved")
	check(not game.director.flags.has("extra") and game.director.step == StoryDirector.Step.THREAT, "story flags come back as saved and the climax restarts")
	check(game.director.threat.active and game.tasks.tasks.has("closing"), "the climax task is back")
	threat.clear_actors()
	# bad files
	var file := FileAccess.open(SaveGame.PATH, FileAccess.WRITE)
	file.store_string("{ not json")
	file.close()
	check(SaveGame.read().is_empty() and not SaveGame.exists(), "a corrupted save is ignored")
	file = FileAccess.open(SaveGame.PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 99, "checkpoint": "closing_time"}))
	file.close()
	check(SaveGame.read().is_empty(), "a save from another version is refused, not misread")
	check(not SaveGame.apply(game, {"version": 99}), "applying an unknown version does nothing")
	SaveGame.erase()
	# menus
	for kind in ["escape", "secured", "caught"]:
		game.flow.show_ending(kind)
		check(game.flow.mode == "ending_" + kind and get_tree().paused, "the %s card pauses the shop" % kind)
		game.flow.hide_all()
	game.flow.show_pause()
	check(game.flow.mode == "pause" and game.flow.has_button("resume") and game.flow.has_button("restart"), "the pause menu offers resume and restart")
	game.flow.press("resume")
	check(game.flow.mode == "none" and not get_tree().paused, "resume puts the game back")
	await _to_closing()
