class_name AmbientDread
extends Node
## Quiet unease: wind outside, tube hum, a compressor that keeps cycling, rare distant sounds.
var _wind: AudioStreamPlayer
var _hum: AudioStreamPlayer
var _distant: AudioStreamPlayer3D
var _rng := RandomNumberGenerator.new()
var _next_event := 0.0

func _ready() -> void:
	name = "AmbientDread"
	_rng.seed = 2026
	_wind = _loop(_noise(6.0, 0.012, 0.5), -27.0)
	_hum = _loop(_hum_stream(), -33.0)
	_distant = AudioStreamPlayer3D.new()
	_distant.position = Vector3(-28.0, 1.5, 30.0)
	_distant.unit_size = 14.0
	_distant.volume_db = -14.0
	add_child(_distant)
	_next_event = _rng.randf_range(25.0, 50.0)

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

func _process(delta: float) -> void:
	_next_event -= delta
	if _next_event > 0.0 or _distant.playing:
		return
	_next_event = _rng.randf_range(40.0, 90.0)
	if _rng.randf() < 0.5:
		_distant.stream = _noise(6.0, 0.05, 0.95)  # a car passing on the road
		_distant.volume_db = -12.0
	else:
		_distant.stream = _knock()  # something settling in the dark
		_distant.volume_db = -10.0
	_distant.play()

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
	for p in [_wind, _hum, _distant]:
		if p:
			p.stop()
			p.stream = null
