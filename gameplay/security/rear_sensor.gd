class_name RearSensor
extends Node
## Reed switch on the rear door. The chime is a consequence of the contact opening, never a free-standing sound.
## On battery (store power out) it still reports, just thinner.
signal reported(kind: String, stamp: String)
var door: Door
var clock: StoryClock
var grid: PowerGrid
var log: Array[Dictionary] = []
var chime_count := 0
var _mains: AudioStreamPlayer3D
var _battery: AudioStreamPlayer3D

func build(world: Node3D, rear_door: Door, story_clock: StoryClock, power: PowerGrid) -> RearSensor:
	name = "RearSensor"
	door = rear_door
	clock = story_clock
	grid = power
	world.add_child(self)
	# The chime box sits over the register so the clerk hears it from the shop floor.
	_mains = Tone.player(_two_tone(784.0, 587.0, 0.32), Vector3(-4.6, 2.3, 3.6), 7.0)
	_battery = Tone.player(Tone.stream(660.0, 380, 0.1, 0.16), Vector3(-4.6, 2.3, 3.6), 6.0)
	for source in [_mains, _battery]:
		source.max_distance = 40.0
		add_child(source)
	door.contact_broken.connect(_on_open)
	door.contact_made.connect(_on_closed)
	return self

func _exit_tree() -> void:
	for source in [_mains, _battery]:
		if source:
			source.stop()
			source.stream = null

func _two_tone(first: float, second: float, level: float) -> AudioStreamWAV:
	var a := Tone.stream(first, 320, 0.25, level)
	var b := Tone.stream(second, 520, 0.25, level)
	a.data = a.data + b.data
	return a

func _on_open() -> void:
	_record("OPEN")
	chime_count += 1
	(_mains if grid.powered("security") else _battery).play()

func _on_closed() -> void:
	_record("CLOSED")

func _record(kind: String) -> void:
	var stamp := clock.text().replace(" AM", "").replace(" PM", "")
	log.append({"kind": kind, "stamp": stamp})
	reported.emit(kind, stamp)

func last_lines(count: int) -> String:
	var lines: Array[String] = []
	for entry in log.slice(maxi(0, log.size() - count)):
		lines.append("REAR DOOR %s  %s" % [entry.kind, entry.stamp])
	return "\n".join(lines)
