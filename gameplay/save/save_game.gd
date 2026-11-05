class_name SaveGame
extends RefCounted
## Versioned checkpoint file. A checkpoint is written at the start of the shift and again just before Leon returns;
## `apply` rebuilds the shop to that moment, for retry after a bad ending and for Continue from the title screen.
const PATH := "user://closing_time_save.json"
const VERSION := 1
const LATE_KEYS := ["threat_begin", "leon_returns"]

static func snapshot(game: Gameplay, checkpoint: String) -> Dictionary:
	var d := game.director
	var player: Node3D = game.player
	var fired: Array = []
	for key in d._fired:
		if not (checkpoint == "closing_time" and key in LATE_KEYS):
			fired.append(key)
	return {
		"version": VERSION,
		"checkpoint": checkpoint,
		"step": StoryDirector.Step.SECURITY_DONE if checkpoint == "closing_time" else StoryDirector.Step.IDLE,
		"flags": d.flags.duplicate(true),
		"fired": fired,
		"chores": d._chores_done.keys(),
		"clock": game.clock.elapsed,
		"phone": game.phone.export_state(),
		"clues_seen": game.clues.seen.keys(),
		"doors": {
			"front": game.security.front_door.locked,
			"rear": game.security.rear_door.locked,
			"office": game.security.office_door.locked},
		"shift": {"filled": game.shift.filled, "bag": game.shift.bag_placed, "latch": game.shift.locked},
		"sales": game.checkout.history.size(),
		"player": [player.global_position.x, player.global_position.y, player.global_position.z, player.rotation.y]}

static func write(data: Dictionary) -> bool:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_warning("could not write save: " + str(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(data))
	return true

## An empty dictionary means there is no usable save (missing, unreadable or from another version).
static func read() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(PATH)) != OK:
		return {}
	var parsed = json.data
	if not parsed is Dictionary or int(parsed.get("version", 0)) != VERSION or not parsed.has("checkpoint"):
		return {}
	return parsed

static func exists() -> bool:
	return not read().is_empty()

static func erase() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))

## Rebuild the shop at the checkpoint. The caller starts the next beat (director.start / threat.begin).
static func apply(game: Gameplay, data: Dictionary) -> bool:
	if int(data.get("version", 0)) != VERSION:
		return false
	var d := game.director
	var sec := game.security
	d.threat.clear_actors()
	sec.hiding.leave()
	sec.landline.reset()
	if sec.cctv.viewing:
		sec.cctv.leave()
		sec.cctv.settle()
	sec.power.reset()
	for door in [sec.front_door, sec.rear_door, sec.office_door]:
		door.set_locked(false, true)
		door.snap(false)
	var doors: Dictionary = data.doors
	sec.front_door.set_locked(doors.front, true)
	sec.rear_door.set_locked(doors.rear, true)
	sec.office_door.set_locked(doors.office, true)
	game.tasks.clear()
	d.flags = (data.flags as Dictionary).duplicate(true)
	d._fired = {}
	for key in data.fired:
		d._fired[key] = true
	d._chores_done = {}
	for chore in data.chores:
		d._chores_done[chore] = true
	game.clock.elapsed = int(data.clock)
	game.clock.changed.emit(game.clock.text())
	game.phone.import_state(data.phone)
	game.clues.reset()
	if data.step >= StoryDirector.Step.ANOMALY:
		game.clues.activate()
		for id in data.clues_seen:
			game.clues.seen[id] = true
	var shift: Dictionary = data.shift
	game.shift.restore(int(shift.filled), bool(shift.bag), bool(shift.latch))
	sec.cctv.revive_feed(0)
	if d.flags.get("rear_cam_lost", false):
		sec.cctv.kill_feed(1)
	else:
		sec.cctv.revive_feed(1)
	d.step = int(data.step)
	d.step_changed.emit(d.step)
	var p: Array = data.player
	game.player.global_position = Vector3(p[0], p[1], p[2])
	game.player.rotation = Vector3(0, p[3], 0)
	game.player.camera.rotation = Vector3.ZERO
	game.player.camera.position.y = 1.62
	game.player.enabled = true
	game.player.velocity = Vector3.ZERO
	return true
