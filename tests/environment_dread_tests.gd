extends SceneTree
## Verify real scene lighting/audio envelopes and their interaction with the breaker.
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	print("DREAD ", "PASS: " if ok else "FAIL: ", label)
	if not ok:
		failures += 1

func _run() -> void:
	var world = (load("res://scenes/world/market_root.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	world.gameplay.flow.hide_all()
	var look = world.get_node("FearsLook")
	var sound = world.ambient_dread
	var power = world.gameplay.security.power
	check(look._flicker_light != null, "weak fixture exists in actual store")
	check(look._flicker_light.position.distance_to(Vector3(-2,2.85,0.1)) < 0.1, "weak fixture is middle aisle")
	var baseline: float = look._flicker_base
	check(baseline > 0.0 and baseline < 0.5, "middle aisle has restrained readable light")
	look._flicker_left = look.SAG_SECONDS
	look._process(look.SAG_SECONDS * 0.5)
	check(look._flicker_light.light_energy < baseline * 0.4, "six-second sag reaches low point smoothly")
	look._process(look.SAG_SECONDS * 0.5)
	check(is_equal_approx(look._flicker_light.light_energy, baseline), "sag returns to original level")
	check(sound._room_tone_base.size() == 2, "both actual refrigeration sources captured")
	sound._start_quiet_cycle()
	sound._update_compressor(3.0)
	for source in sound._room_tone_base:
		check(is_equal_approx(source.volume_db, float(sound._room_tone_base[source])-28.0), "compressor settles into quiet interval")
	power.flip("main", false)
	look._process(0.1)
	var paused_states := {}
	for source in sound._room_tone_base:
		paused_states[source] = source.stream_paused
	sound._update_compressor(3.0)
	check(is_zero_approx(look._flicker_light.light_energy), "atmosphere cannot relight a tripped circuit")
	for source in sound._room_tone_base:
		check(source.stream_paused == paused_states[source], "quiet cycle preserves breaker-owned audio pause state")
	power.flip("main", true)
	sound._update_compressor(20.0)
	for source in sound._room_tone_base:
		check(is_equal_approx(source.volume_db, float(sound._room_tone_base[source])), "compressor restores exact normal volume")
	print("ENVIRONMENT DREAD TESTS COMPLETE failures=",failures)
	await world.finish_run(1 if failures else 0)
