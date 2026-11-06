class_name Soundscape
extends Node3D
## Where you are, by ear: hard tile and a small-room reflection inside, rain on the lot that you hear through the
## glass and roof, louder in the open doorway and full once you step out, and your own steps on each surface.
const INTERIOR := AABB(Vector3(-9.6, -0.2, -6.05), Vector3(19.2, 3.6, 12.1))
const FRONT_OPENING := Vector3(1.7, 1.0, 6.0)
const REAR_OPENING := Vector3(4.25, 1.0, -6.05)
const ROOM_BUS := "Room"
const WEATHER_BUS := "Weather"
const WALK_STRIDE := 0.72
const RUN_STRIDE := 0.95
var game: Gameplay
var player: CharacterBody3D
var outdoors := 0.0  # 0 deep inside .. 1 standing in the rain, smoothed
var steps_taken := 0
var _rain: AudioStreamPlayer
var _steps: AudioStreamPlayer3D
var _stride := 0.0
var _last_feet := Vector3.ZERO
var _filter: AudioEffectLowPassFilter

func setup(owner_game: Gameplay) -> Soundscape:
	game = owner_game
	player = game.player
	name = "Soundscape"
	_ensure_buses()
	_build_room()
	_rain = AudioStreamPlayer.new()
	_rain.stream = _rain_loop()
	_rain.bus = WEATHER_BUS
	_rain.volume_db = -20.0
	_rain.autoplay = true
	add_child(_rain)
	_steps = AudioStreamPlayer3D.new()
	_steps.unit_size = 6.0
	_steps.position = Vector3(0, 0.05, 0)
	player.add_child(_steps)
	_last_feet = player.global_position
	return self

func _ensure_buses() -> void:
	if AudioServer.get_bus_index(ROOM_BUS) < 0:
		AudioServer.add_bus()
		var room := AudioServer.bus_count - 1
		AudioServer.set_bus_name(room, ROOM_BUS)
		AudioServer.set_bus_send(room, "Master")
		var reverb := AudioEffectReverb.new()
		reverb.room_size = 0.32  # a shop floor and two back rooms: short, boxy, not a hall
		reverb.damping = 0.65
		reverb.spread = 0.6
		reverb.dry = 0.0
		reverb.wet = 0.5
		reverb.predelay_msec = 18.0
		AudioServer.add_bus_effect(room, reverb)
	if AudioServer.get_bus_index(WEATHER_BUS) < 0:
		AudioServer.add_bus()
		var weather := AudioServer.bus_count - 1
		AudioServer.set_bus_name(weather, WEATHER_BUS)
		AudioServer.set_bus_send(weather, "Master")
		AudioServer.add_bus_effect(weather, AudioEffectLowPassFilter.new())
	_filter = AudioServer.get_bus_effect(AudioServer.get_bus_index(WEATHER_BUS), 0) as AudioEffectLowPassFilter

## Any 3D sound made inside the store also sends into the room reflection.
func _build_room() -> void:
	var room := Area3D.new()
	room.name = "RoomAcoustics"
	room.monitoring = false
	room.collision_mask = 0
	room.reverb_bus_enabled = true
	room.reverb_bus_name = ROOM_BUS
	room.reverb_bus_amount = 0.35
	room.reverb_bus_uniformity = 0.4
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = INTERIOR.size
	shape.shape = box
	room.add_child(shape)
	add_child(room)
	room.position = INTERIOR.get_center()  # the soundscape sits at the world origin

func is_inside(point: Vector3) -> bool:
	return INTERIOR.has_point(Vector3(point.x, 1.0, point.z))

func _physics_process(delta: float) -> void:
	if player == null:
		return
	var target := 1.0 if not is_inside(player.global_position) else _doorway_leak()
	outdoors = move_toward(outdoors, target, delta * 1.5)
	# Inside, rain is a dull roar on the roof and glass; in an open doorway the hiss comes through; outside it is all around.
	_filter.cutoff_hz = lerpf(650.0, 14000.0, outdoors * outdoors)
	_rain.volume_db = lerpf(-21.0, -9.0, outdoors)
	_footsteps()

## How much of the outside reaches you through an open door, by distance to it.
func _doorway_leak() -> float:
	var leak := 0.0
	var feet := player.global_position + Vector3(0, 1.0, 0)
	var doors := [[game.security.front_door, FRONT_OPENING], [game.security.rear_door, REAR_OPENING]]
	for pair in doors:
		var door := pair[0] as Door
		if door != null and not door.is_closed():
			leak = maxf(leak, 0.6 * (1.0 - smoothstep(0.5, 6.0, feet.distance_to(pair[1]))))
	return leak

## A step every stride of real ground covered, so the rhythm matches the speed and stops dead when you do.
func _footsteps() -> void:
	var feet := player.global_position
	var moved := Vector2(feet.x - _last_feet.x, feet.z - _last_feet.z).length()
	_last_feet = feet
	if not player.is_on_floor() or moved > 1.0 or not player.enabled:  # teleports and cutscenes are not walking
		_stride = 0.0
		return
	var speed := moved / maxf(get_physics_process_delta_time(), 0.0001)
	var running := speed > 2.4
	_stride += moved
	if _stride < (RUN_STRIDE if running else WALK_STRIDE):
		return
	_stride = 0.0
	steps_taken += 1
	var inside := is_inside(feet)
	_steps.stream = Foley.take("step_tile" if inside else "step_wet")
	_steps.volume_db = (-13.0 if running else -18.0) + (0.0 if inside else 1.5)
	_steps.pitch_scale = randf_range(0.93, 1.06)
	_steps.play()

## Four seconds of rain on asphalt: dense hiss, low roar and scattered drops, crossfaded so the loop has no seam.
func _rain_loop() -> AudioStreamWAV:
	var rate := 22050
	var count := rate * 4
	var fade := rate / 4
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var raw := PackedFloat32Array()
	raw.resize(count + fade)
	var hiss := 0.0
	var hiss_low := 0.0
	var roar := 0.0
	for i in raw.size():
		var n := rng.randf_range(-1.0, 1.0)
		hiss += (n - hiss) * 0.55
		hiss_low += (n - hiss_low) * 0.12
		roar += (n - roar) * 0.015
		raw[i] = (hiss - hiss_low) * 0.5 + roar * 1.1
	for d in 900:
		var at := rng.randi_range(0, raw.size() - 200)
		var freq := rng.randf_range(1800.0, 5200.0)
		var level := rng.randf_range(0.02, 0.09)
		for k in 160:
			raw[at + k] += sin(TAU * freq * k / rate) * exp(-k / 30.0) * level
	var out := PackedFloat32Array()
	out.resize(count)
	for i in count:
		out[i] = raw[i]
		if i < fade:  # the tail of the take blends into its head
			var w := float(i) / fade
			out[i] = raw[i] * w + raw[count + i] * (1.0 - w)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		data.encode_s16(i * 2, int(clampf(out[i] * 0.8, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = count
	return wav

func _exit_tree() -> void:
	for p in [_rain, _steps]:
		if is_instance_valid(p):
			p.stop()
			p.stream = null
