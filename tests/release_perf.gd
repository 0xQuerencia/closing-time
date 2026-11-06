class_name ReleasePerf
extends Node
## Frame times in the moments players feel: walking the store, a customer coming in, the CCTV desk, and the hunt.
## Run: godot --path . --resolution 1280x720 -- --release-perf
## The GPU on the dev machine clocks down when idle, so a single long frame right after a quiet stretch can be the
## card ramping up, not the game. Each scenario is preceded by a warm-up, and a frame over 50 ms is reported with
## what was happening so it can be checked by hand.
const WALK := [Vector3(-6.9, 0.05, 5.2), Vector3(-3.6, 0.05, 3.0), Vector3(-1.5, 0.05, 2.6), Vector3(-1.5, 0.05, -4.0),
	Vector3(3.0, 0.05, -1.0), Vector3(4.25, 0.05, -2.0), Vector3(4.25, 0.05, -5.0), Vector3(4.25, 0.05, 0.5),
	Vector3(1.7, 0.05, 4.4), Vector3(1.7, 0.05, 9.0), Vector3(-2.0, 0.05, 11.0), Vector3(1.7, 0.05, 4.4)]
const HITCH_MS := 50.0
var game: Gameplay
var player: CharacterBody3D
var _times: Array[float] = []
var _hitches: Array[String] = []
var _scenario := ""
var _last_usec := 0
var _recording := false
var results: Array[Dictionary] = []

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _recording and _last_usec > 0:
		var ms := (now - _last_usec) / 1000.0
		_times.append(ms)
		if ms > HITCH_MS:
			_hitches.append("%s: %.0f ms at frame %d" % [_scenario, ms, _times.size()])
	_last_usec = now

func run(market: Node3D) -> void:
	game = market.gameplay
	player = market.player
	player.require_mouse_capture = false
	game.flow.press("start")
	await _warm(3.0)
	await _measure("walk the store", _walk_route)
	await _measure("customer arrives", _customer_arrives)
	await _measure("cctv desk", _cctv)
	await _measure("the hunt", _hunt)
	print("---- RELEASE PERF (real renderer, %s) ----" % RenderingServer.get_video_adapter_name())
	for h in _hitches:
		print("HITCH ", h)
	print("RELEASE PERF COMPLETE")
	await market.finish_run(0)

func _warm(seconds: float) -> void:
	_recording = false
	await get_tree().create_timer(seconds).timeout

func _measure(label: String, scenario: Callable) -> void:
	await _warm(1.5)
	_scenario = label
	_times.clear()
	_last_usec = 0
	_recording = true
	await scenario.call()
	_recording = false
	var sorted := _times.duplicate()
	sorted.sort()
	var total := 0.0
	var over := 0
	for t in sorted:
		total += t
		if t > 33.3:
			over += 1
	var n := maxi(sorted.size(), 1)
	results.append({"name": label, "frames": sorted.size(), "avg": total / n, "p95": sorted[int(n * 0.95)] if sorted.size() > 0 else 0.0,
		"p99": sorted[int(n * 0.99)] if sorted.size() > 0 else 0.0, "max": sorted.back() if sorted.size() > 0 else 0.0, "over33": over})
	var r: Dictionary = results.back()
	print("PERF %-18s frames %5d  avg %5.1f ms  p95 %5.1f  p99 %5.1f  max %6.1f  over 33ms %d" % [r.name, r.frames, r.avg, r.p95, r.p99, r.max, r.over33])

## Walk the whole loop at the player's speed, looking where you go: shop floor, back hall, out into the rain and back.
func _walk_route() -> void:
	player.enabled = true
	player.global_position = WALK[0]
	for i in range(1, WALK.size()):
		var from: Vector3 = player.global_position
		var to: Vector3 = WALK[i]
		var d := to - from
		player.rotation.y = atan2(-d.x, -d.z)
		var seconds := d.length() / 1.9
		var t := 0.0
		while t < seconds:
			await get_tree().process_frame
			t += get_process_delta_time()
			player.global_position = from.lerp(to, minf(t / seconds, 1.0))
			player.camera.rotation.x = sin(t * 0.7) * 0.15

## A shopper is instanced, walks in through the door and down the aisle while the clerk watches from the counter.
func _customer_arrives() -> void:
	player.global_position = Vector3(-5.6, 0.05, 5.0)
	player.rotation.y = -0.6
	var customer := game.spawn_customer()
	var t := 0.0
	while t < 14.0 and is_instance_valid(customer):
		await get_tree().process_frame
		t += get_process_delta_time()
		var d: Vector3 = customer.global_position - player.global_position
		player.rotation.y = atan2(-d.x, -d.z)

## Sit at the monitor, flick through every camera, review tape, leave.
func _cctv() -> void:
	player.global_position = Vector3(7.6, 0.05, -4.3)
	var cctv := game.security.cctv
	cctv.enter()
	await get_tree().create_timer(1.0).timeout
	for round_index in 2:
		for i in cctv.feeds.size():
			cctv.select(i)
			await get_tree().create_timer(0.8).timeout
	cctv._toggle_playback()
	for i in 20:
		cctv._scrub_tape(-1)
		await get_tree().create_timer(0.1).timeout
	cctv._toggle_playback()
	cctv.leave()
	await get_tree().create_timer(1.0).timeout

## Leon in the building, seeing you, running you down the aisle while you back away.
func _hunt() -> void:
	var leon := game.security.spawn_stalker()
	leon.inside = true
	leon.global_position = Vector3(-1.5, 0.0, -4.0)
	player.global_position = Vector3(-1.5, 0.05, 1.5)
	player.rotation.y = 0.0
	leon.begin_hunt()
	var t := 0.0
	while t < 10.0 and is_instance_valid(leon) and leon.state != Stalker.State.CAUGHT:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		player.global_position.z = minf(player.global_position.z + 1.6 * dt, 4.0)
	await get_tree().create_timer(1.5).timeout
