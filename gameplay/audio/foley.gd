class_name Foley
## Recorded shoe steps and synthesised object one-shots: products in the hand and door hardware.
## Every sound has a few takes so repeats do not machine-gun. Built once and cached.
const RATE := 22050
const TAKES := 4
static var _bank: Dictionary = {}
static var _last_step := -1
const STEPS := [
	preload("res://assets/audio/footsteps/footstep_concrete_000.wav"),
	preload("res://assets/audio/footsteps/footstep_concrete_001.wav"),
	preload("res://assets/audio/footsteps/footstep_concrete_002.wav"),
	preload("res://assets/audio/footsteps/footstep_concrete_003.wav"),
	preload("res://assets/audio/footsteps/footstep_concrete_004.wav")]


## A random take of `kind`. Kinds: step_tile, step_wet, metal, plastic, paper, bag, card, latch, door_shut, glass_shut, bolt.
static func take(kind: String) -> AudioStreamWAV:
	if kind in ["step_tile", "step_wet"]:
		# Loaded during scene setup, never synthesised on the first walking frame.
		_last_step = (_last_step + 1 + randi() % (STEPS.size() - 1)) % STEPS.size()
		return STEPS[_last_step]
	if not _bank.has(kind):
		var takes: Array[AudioStreamWAV] = []
		for i in TAKES:
			takes.append(_build(kind, hash(kind) + i * 7919))
		_bank[kind] = takes
	var list: Array = _bank[kind]
	return list[randi() % list.size()]

## What a product sounds like in the hand, from its catalogue id.
static func handling_kind(product_id: String) -> String:
	match product_id:
		"cola", "coffee":
			return "metal"
		"water":
			return "plastic"
		"paper", "cup_coffee":
			return "paper"
		"crisps", "trash_bag":
			return "bag"
	return "card"

## A one-shot at a world position that frees itself; for sounds whose owner may be gone before it ends.
static func play_at(parent: Node, kind: String, at: Vector3, db := -10.0, pitch := 1.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = take(kind)
	p.volume_db = db
	p.pitch_scale = pitch * randf_range(0.95, 1.05)
	p.unit_size = 3.0
	p.max_distance = 20.0
	p.finished.connect(p.queue_free)
	parent.add_child(p)
	p.global_position = at
	p.play()

static func _build(kind: String, seed_value: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out: PackedFloat32Array
	match kind:
		"metal":
			out = _metal(rng)
		"plastic":
			out = _plastic(rng)
		"paper":
			out = _rustle(rng, 0.16, 0.05, 0.5)
		"bag":
			out = _crinkle(rng, 0.26)
		"latch":
			out = _latch(rng)
		"door_shut":
			out = _shut(rng, false)
		"glass_shut":
			out = _shut(rng, true)
		"bolt":
			out = _bolt(rng)
		_:
			out = _card(rng)
	return _wav(out)

# --- generators -----------------------------------------------------------------------------------

## A can or tin: a short ring of inharmonic partials over a small thud.
static func _metal(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := _silence(0.22)
	var base := rng.randf_range(1500.0, 1900.0)
	for ratio in [1.0, 1.59, 2.31, 3.07]:
		_tick(out, 0.0, base * ratio, rng.randf_range(0.03, 0.07), 0.16 / ratio)
	_knock(out, 0.0, 180.0, 0.03, 0.3)
	_noise_burst(out, rng, 0.0, 0.006, 0.3, 0.6)
	return out

## A plastic bottle: a hollow knock and a couple of crackles from the thin wall.
static func _plastic(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := _silence(0.2)
	_knock(out, 0.0, rng.randf_range(420.0, 560.0), 0.035, 0.32)
	_knock(out, 0.0, 160.0, 0.03, 0.25)
	for i in 4:
		_tick(out, rng.randf_range(0.01, 0.09), rng.randf_range(1800.0, 3400.0), 0.006, rng.randf_range(0.08, 0.16))
	return out

## Cardboard and boxed goods: a soft thud and a brief scrape.
static func _card(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := _silence(0.18)
	_knock(out, 0.0, rng.randf_range(140.0, 180.0), 0.04, 0.5)
	_noise_burst(out, rng, 0.0, 0.05, 0.3, 0.2)
	return out

## Paper, a cup sleeve: filtered noise with a fluttering envelope.
static func _rustle(rng: RandomNumberGenerator, seconds: float, attack: float, level: float) -> PackedFloat32Array:
	var out := _silence(seconds)
	var low := 0.0
	var lower := 0.0
	var flutter := rng.randf_range(28.0, 45.0)
	for i in out.size():
		var t := float(i) / RATE
		var env := minf(1.0, t / attack) * pow(1.0 - t / seconds, 2.0)
		var n := rng.randf_range(-1.0, 1.0)
		low += (n - low) * 0.35
		lower += (n - lower) * 0.05
		var band := low - lower
		out[i] += band * env * level * (0.6 + 0.4 * absf(sin(TAU * flutter * t)))
	return out

## Foil bags and bin liners: lots of tiny random crackles.
static func _crinkle(rng: RandomNumberGenerator, seconds: float) -> PackedFloat32Array:
	var out := _rustle(rng, seconds, 0.02, 0.22)
	for i in 38:
		var at := rng.randf_range(0.0, seconds * 0.85)
		var fade := 1.0 - at / seconds
		_tick(out, at, rng.randf_range(2200.0, 6500.0), rng.randf_range(0.002, 0.006), rng.randf_range(0.05, 0.2) * fade)
	return out

## A door latch: two metal clicks as the tongue slides and drops.
static func _latch(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := _silence(0.16)
	var gap := rng.randf_range(0.04, 0.07)
	_tick(out, 0.0, rng.randf_range(2300.0, 2900.0), 0.012, 0.32)
	_tick(out, gap, rng.randf_range(1900.0, 2400.0), 0.018, 0.4)
	_noise_burst(out, rng, 0.0, gap, 0.08, 0.4)
	_knock(out, gap, 260.0, 0.02, 0.18)
	return out

## A door closing in its frame: a deep thump, the latch catching, and for glass a short rattle.
static func _shut(rng: RandomNumberGenerator, glass: bool) -> PackedFloat32Array:
	var out := _silence(0.5)
	_knock(out, 0.0, rng.randf_range(62.0, 74.0), 0.12, 0.7)
	_knock(out, 0.0, 140.0, 0.05, 0.35)
	_knock(out, 0.0, rng.randf_range(320.0, 380.0), 0.03, 0.25)  # the panel itself, not just the floor
	_noise_burst(out, rng, 0.0, 0.03, 0.6, 0.45)
	var latch_at := rng.randf_range(0.05, 0.08)
	_tick(out, latch_at, rng.randf_range(2100.0, 2500.0), 0.015, 0.22)
	if glass:
		for i in 10:
			_tick(out, rng.randf_range(0.0, 0.12), rng.randf_range(3200.0, 5600.0), rng.randf_range(0.02, 0.05), rng.randf_range(0.03, 0.07))
	return out

## A deadbolt or key turn: click, a short metal slide, a heavier click.
static func _bolt(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := _silence(0.3)
	_tick(out, 0.0, 2600.0, 0.01, 0.25)
	_noise_burst(out, rng, 0.02, 0.09, 0.07, 0.7)
	_tick(out, 0.12, rng.randf_range(1500.0, 1800.0), 0.03, 0.45)
	_knock(out, 0.12, 220.0, 0.03, 0.3)
	return out

# --- building blocks ------------------------------------------------------------------------------

static func _silence(seconds: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(RATE * seconds))
	return out

## A decaying sine with a little pitch drop: wood, shoe, cardboard.
static func _knock(out: PackedFloat32Array, at: float, freq: float, decay: float, level: float) -> void:
	var start := int(at * RATE)
	var phase := 0.0
	for i in range(start, out.size()):
		var age := float(i - start) / RATE
		if age > decay * 6.0:
			break
		phase += TAU * freq * (1.0 - 0.25 * minf(1.0, age / decay)) / RATE
		out[i] += sin(phase) * exp(-age / decay) * level

## A short bright partial: metal, glass, plastic.
static func _tick(out: PackedFloat32Array, at: float, freq: float, decay: float, level: float) -> void:
	var start := int(at * RATE)
	for i in range(start, out.size()):
		var age := float(i - start) / RATE
		if age > decay * 6.0:
			break
		out[i] += sin(TAU * freq * age) * exp(-age / decay) * level

## Noise with one-pole smoothing (`smooth` 1 = raw, small = dark).
static func _noise_burst(out: PackedFloat32Array, rng: RandomNumberGenerator, at: float, decay: float, level: float, smooth: float) -> void:
	var start := int(at * RATE)
	var y := 0.0
	for i in range(start, out.size()):
		var age := float(i - start) / RATE
		if age > decay * 6.0:
			break
		y += (rng.randf_range(-1.0, 1.0) - y) * smooth
		out[i] += y * exp(-age / decay) * level

static func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var peak := 0.0
	for s in samples:
		peak = maxf(peak, absf(s))
	var gain := 0.85 / peak if peak > 0.0 else 1.0  # every take peaks the same; loudness is set where it plays
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i] * gain, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	return wav
