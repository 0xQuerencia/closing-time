extends SceneTree
## Run in an isolated user-data directory. Re-enter while staff movement is in flight.

const START := "res://scenes/world/market_root.tscn"
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	SaveGame.erase()
	OpeningCheckpoint.erase()
	change_scene_to_file(START)
	await scene_changed
	var first_object_count := 0
	for cycle in range(1, 5):
		var title := current_scene
		var title_game = title.gameplay
		var camera: WeakRef = weakref(title_game.security.cctv.feeds[1].viewport)
		var old_title: WeakRef = weakref(title)
		_check(title_game.flow.press("start"), "New Game")
		await scene_changed
		_check(old_title.get_ref() == null and camera.get_ref() == null, "title and feed freed")
		var room := current_scene
		_check(room.scene_file_path.ends_with("apartment.tscn"), "apartment open")
		var old_room: WeakRef = weakref(room)
		room._close_prologue()
		for item in ["shift_read", "keys_taken", "vest_taken", "apartment_exit"]:
			room._use(item)
		await scene_changed
		_check(old_room.get_ref() == null, "apartment freed")
		var road := current_scene
		var old_road: WeakRef = weakref(road)
		var engine: WeakRef = weakref(road.engine)
		_check(road.scene_file_path.ends_with("route9.tscn") and road.engine.playing, "route and engine active")
		road.skip.pressed.emit()
		await scene_changed
		_check(old_road.get_ref() == null and engine.get_ref() == null, "route and audio player freed")
		var market := current_scene
		var old_market: WeakRef = weakref(market)
		for frame in 4:
			await process_frame
		var game: Gameplay = market.gameplay
		var cctv := game.security.cctv
		var old_cctv: WeakRef = weakref(cctv)
		var old_staff: WeakRef = weakref(game.director.production.staff.dina)
		_check(get_nodes_in_group("power_grid").size() == 1 and get_nodes_in_group("player").size() == 1,
			"one power grid and one player")
		cctv.enter()
		cctv.settle()
		cctv.select(1)
		cctv._toggle_playback()
		_check(cctv.playback and cctv._playback_frames.size() == 4, "archive opens after scene rebuild")
		cctv.leave()
		cctv.settle()
		game.director.production._on_dialogue_finished("production_handover")
		for frame in 4:
			await physics_frame
		game.flow.show_pause()
		_check(game.flow.press("title"), "return to title with Dina moving")
		await scene_changed
		await create_timer(.2, true, false, true).timeout
		_check(old_market.get_ref() == null and old_cctv.get_ref() == null and old_staff.get_ref() == null,
			"market, recorder and moving staff freed")
		var objects := int(Performance.get_monitor(Performance.OBJECT_COUNT))
		if cycle == 1:
			first_object_count = objects
		else:
			_check(objects <= first_object_count + 1, "object count returns to its first-cycle level")
		var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
		_check(orphans == 0, "no orphan nodes after returning to the title")
		print("SCENE RELOAD cycle=%d nodes=%d objects=%d resources=%d orphans=%d" % [cycle, get_node_count(),
			objects, Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT), orphans])
	_check(current_scene.gameplay.flow.mode == "title", "normal title remains usable")
	print("SCENE RELOAD TESTS COMPLETE failures=", failures)
	await current_scene.finish_run(failures)

func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("LIFECYCLE FAIL ", label)
