class_name AmbientDread
extends Node
## Quiet unease: wind outside, tube hum, a compressor that keeps cycling, rare distant sounds.
var _wind: AudioStreamPlayer
var _hum: AudioStreamPlayer
var _distant: AudioStreamPlayer3D
var _radio: AudioStreamPlayer3D
var _heartbeat: AudioStreamPlayer
var _breath: AudioStreamPlayer
var _game: Gameplay
var _power: PowerGrid
var _rng := RandomNumberGenerator.new()
var _next_event := 0.0
var _next_radio := 0.0
var _main_was_cut := false
var _room_tone_base: Dictionary = {}
var _next_quiet := 38.0
var _quiet_age := -1.0
const QUIET_SECONDS := 13.0

func _ready() -> void:
	name = "AmbientDread"
	_rng.seed = 2026
	_wind = _loop(_noise(6.0, 0.012, 0.5), -27.0)
	_hum = _loop(_hum_stream(), -33.0)
	_distant = AudioStreamPlayer3D.new()
	_distant.position = Vector3(1.5, 0.7, 14.0)
	_distant.unit_size = 12.0
	_distant.volume_db = -20.0
	add_child(_distant)
	_heartbeat = _loop(_heartbeat_stream(), -80.0)
	_breath = _loop(_breath_stream(), -80.0)
	for source in get_tree().get_nodes_in_group("power_hum"):
		if source is AudioStreamPlayer3D:
			_room_tone_base[source] = source.volume_db
	_next_event = _rng.randf_range(25.0, 50.0)
	_next_radio = _rng.randf_range(72.0, 124.0)

func bind_gameplay(game: Gameplay) -> void:
	_game = game
	_power = game.security.power
	_power.changed.connect(_on_power_changed)
	_on_power_changed()

func _on_power_changed() -> void:
	if _power == null:
		return
	if not _power.main_on:
		_main_was_cut = true
		_hum.stream_paused = true
	elif _main_was_cut:
		# The compressor comes back a little off pitch after the breaker reset.
		_hum.pitch_scale = 0.975
		_hum.stream_paused = false
		_main_was_cut = false

func _loop(stream: AudioStreamWAV, db: float) -> AudioStreamPlayer:
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = stream.data.size() / 2
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = db
	add_child(p)
	p.play()
	return p

func _wav(samples: PackedFloat32Array, rate: int) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav

## Low-passed noise with a slow swell, looped.
func _noise(seconds: float, smoothing: float, depth: float) -> AudioStreamWAV:
	var rate := 16000
	var count := int(rate * seconds)
	var out := PackedFloat32Array()
	out.resize(count)
	var y := 0.0
	for i in count:
		y += (_rng.randf_range(-1.0, 1.0) - y) * smoothing
		var swell := 1.0 - depth + depth * (0.5 + 0.5 * sin(TAU * i / count * 2.0))
		out[i] = y * 5.5 * swell
	return _wav(out, rate)

func _hum_stream() -> AudioStreamWAV:
	var rate := 16000
	var count := rate * 2  # whole cycles of 60/120/180 Hz so the loop is seamless
	var out := PackedFloat32Array()
	out.resize(count)
	for i in count:
		var t := float(i) / rate
		out[i] = 0.22 * sin(TAU * 120.0 * t) + 0.12 * sin(TAU * 60.0 * t) + 0.05 * sin(TAU * 180.0 * t) + _rng.randf_range(-0.01, 0.01)
	return _wav(out, rate)

func _heartbeat_stream() -> AudioStreamWAV:
	var rate := 16000
	var out := PackedFloat32Array()
	out.resize(rate * 2)
	for i in out.size():
		var t := float(i) / rate
		var beat := 0.0
		for hit in [0.04, 0.30]:
			var age: float = t - hit
			if age >= 0.0 and age < 0.2:
				var env := exp(-age * 25.0)
				beat += (sin(TAU * 54.0 * age) * 0.6 + sin(TAU * 83.0 * age) * 0.18) * env
		out[i] = beat * 0.38
	return _wav(out, rate)

func _breath_stream() -> AudioStreamWAV:
	var rate := 16000
	var out := PackedFloat32Array()
	out.resize(rate * 4)
	var filtered := 0.0
	for i in out.size():
		var t := float(i) / rate
		var phase := fposmod(t, 4.0) / 4.0
		var envelope := pow(maxf(0.0, sin(PI * phase)), 1.7)
		filtered += (_rng.randf_range(-1.0, 1.0) - filtered) * 0.035
		# Soft, filtered air with a slight throat resonance. It is intentionally not a gasp.
		var resonance := sin(TAU * 260.0 * t) * 0.035 + sin(TAU * 390.0 * t) * 0.018
		out[i] = (filtered * 0.42 + resonance) * envelope * 0.33
	return _wav(out, rate)

func _process(delta: float) -> void:
	_update_compressor(delta)
	_update_body_audio()
	_next_radio -= delta
	if _next_radio <= 0.0:
		_play_radio_fault()
	_next_event -= delta
	if _next_event > 0.0 or _distant.playing:
		return
	_next_event = _rng.randf_range(40.0, 90.0)
	var event := _rng.randi_range(0, 2)
	if event == 0:
		_distant.stream = _engine_idle()
		_distant.volume_db = -19.0
	elif event == 1:
		_distant.stream = _car_door()
		_distant.volume_db = -17.0
	else:
		_distant.stream = _knock()
		_distant.volume_db = -18.0
	_distant.play()
	_update_body_audio()

## Compressors briefly cycle down: the wind and small distant noises become exposed.
## Volume envelopes preserve PowerGrid's ownership of stream pause/restart state.
func _update_compressor(delta: float) -> void:
	if _power != null and not _power.main_on:
		return
	if _quiet_age < 0.0:
		_next_quiet -= delta
		if _next_quiet <= 0.0:
			_start_quiet_cycle()
		return
	_quiet_age += delta
	var attenuation := 0.0
	if _quiet_age < 2.0:
		attenuation = lerpf(0.0, -28.0, smoothstep(0.0, 2.0, _quiet_age))
	elif _quiet_age < 6.0:
		attenuation = -28.0
	else:
		attenuation = lerpf(-28.0, 0.0, smoothstep(6.0, QUIET_SECONDS, _quiet_age))
	_hum.volume_db = -33.0 + attenuation
	for source in _room_tone_base:
		if is_instance_valid(source):
			source.volume_db = float(_room_tone_base[source]) + attenuation
	if _quiet_age >= QUIET_SECONDS:
		_quiet_age = -1.0
		_next_quiet = _rng.randf_range(68.0, 115.0)

func _start_quiet_cycle() -> void:
	_quiet_age = 0.0

func _play_radio_fault() -> void:
	if _radio == null:
		_radio = AudioStreamPlayer3D.new()
		_radio.position = Vector3(-8.45, 1.06, 0.34)
		_radio.unit_size = 1.8
		_radio.max_distance = 9.0
		_radio.volume_db = -27.0
		add_child(_radio)
	_radio.stream = _radio_static()
	_radio.play()
	_next_radio = _rng.randf_range(95.0, 165.0)

func _radio_static() -> AudioStreamWAV:
	var rate := 16000
	var out := PackedFloat32Array()
	out.resize(int(rate * 0.65))
	var filtered := 0.0
	for i in out.size():
		var t := float(i) / rate
		var fade := minf(1.0, minf(t / 0.025, (0.65 - t) / 0.11))
		filtered += (_rng.randf_range(-1.0, 1.0) - filtered) * 0.16
		var sweep := sin(TAU * (520.0 * t + 160.0 * t * t)) * 0.07
		out[i] = (filtered * 0.72 + sweep) * fade
	return _wav(out, rate)

func _engine_idle() -> AudioStreamWAV:
	var rate := 16000
	var count := rate * 7
	var out := PackedFloat32Array()
	out.resize(count)
	var low_noise := 0.0
	for i in count:
		var t := float(i) / rate
		low_noise += (_rng.randf_range(-1.0, 1.0) - low_noise) * 0.008
		var pulse := 0.72 + 0.28 * sin(TAU * 1.8 * t)
		var fade := minf(1.0, minf(t / 0.7, (7.0 - t) / 0.7))
		out[i] = (sin(TAU * 43.0 * t) * 0.22 + sin(TAU * 86.0 * t) * 0.09 + low_noise * 0.7) * pulse * fade
	return _wav(out, rate)

func _car_door() -> AudioStreamWAV:
	var rate := 16000
	var out := PackedFloat32Array()
	out.resize(int(rate * 1.15))
	for i in out.size():
		var t := float(i) / rate
		var impact := 0.0
		for hit in [0.12, 0.23]:
			var age: float = t - hit
			if age >= 0.0 and age < 0.25:
				impact += sin(TAU * (72.0 - age * 80.0) * age) * exp(-age * 22.0)
		var latch_age := t - 0.34
		var latch := sin(TAU * 1700.0 * latch_age) * exp(-latch_age * 75.0) if latch_age >= 0.0 else 0.0
		out[i] = impact * 0.55 + latch * 0.08
	return _wav(out, rate)

func _update_body_audio() -> void:
	if _game == null:
		_heartbeat.volume_db = -80.0
		_breath.volume_db = -80.0
		return
	var distance := 100000.0
	for actor in get_tree().get_nodes_in_group("leon_presence"):
		if is_instance_valid(actor) and actor is Node3D:
			distance = minf(distance, _game.player.global_position.distance_to((actor as Node3D).global_position))
	if is_instance_valid(_game.security.intruder):
		var threat: Intruder = _game.security.intruder
		var active := threat.inside
		if threat is Stalker:
			active = (threat as Stalker).state != Stalker.State.DORMANT and (threat as Stalker).state != Stalker.State.LEAVING
		if active:
			distance = minf(distance, _game.player.global_position.distance_to(threat.global_position))
	if distance >= 100000.0:
		_heartbeat.volume_db = -80.0
		_breath.volume_db = -80.0
		return
	var intensity := 1.0 - smoothstep(3.0, 11.0, distance)
	_heartbeat.volume_db = lerpf(-80.0, -29.0, intensity)
	_breath.volume_db = lerpf(-80.0, -34.0, intensity)

func _knock() -> AudioStreamWAV:
	var rate := 16000
	var out := PackedFloat32Array()
	out.resize(rate)
	for hit in [0.0, 0.55]:
		for i in int(rate * 0.28):
			var idx := int(hit * rate) + i
			if idx < out.size():
				out[idx] += sin(TAU * 78.0 * i / rate) * exp(-i / (rate * 0.05)) * 0.9
	return _wav(out, rate)

func _exit_tree() -> void:
	for p in [_wind, _hum, _distant, _radio, _heartbeat, _breath]:
		if p:
			p.stop()
			p.stream = null
