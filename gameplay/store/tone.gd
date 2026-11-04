class_name Tone
## Tiny procedural sound effects so interactions have audio without new asset files.
static func stream(freq: float, ms: int, overtone := 0.0, level := 0.3) -> AudioStreamWAV:
	var rate := 22050
	var count := rate * ms / 1000
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var fade := 1.0 - float(i) / count
		var s := sin(TAU * freq * i / rate) + overtone * sin(TAU * freq * 2.76 * i / rate)
		data.encode_s16(i * 2, int(clampf(s * level * fade * fade, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav

static func player(stream_data: AudioStreamWAV, pos: Vector3, unit_size := 4.0) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream_data
	p.unit_size = unit_size
	p.position = pos
	return p
