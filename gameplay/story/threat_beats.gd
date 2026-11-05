class_name ThreatBeats
extends Node
## M5 climax. Leon comes back through the rear with the spare key and hunts the shop. Three ways out: get out the
## front door, hold the locked office until the police arrive, or get caught. The checkpoint sits just before he returns.
signal ending(kind: String)
const ESCAPE_Z := 7.3
const OFFICE_MIN_X := 5.0
const OFFICE_MAX_Z := -2.5
var director: StoryDirector
var game: Gameplay
var sec: Security
var active := false
var ended := ""
var stalker: Stalker
var threat_time := 0.0
var police_left := -1.0
var entry_delay := 14.0
var police_eta := 30.0
var rescue_after := 240.0
var siren_lights: Array[OmniLight3D] = []
var _siren_tone: AudioStreamPlayer3D
var _siren_flip := 0.0

func setup(owner: StoryDirector) -> ThreatBeats:
	director = owner
	game = owner.game
	sec = game.security
	name = "ThreatBeats"
	sec.landline.call_started.connect(_on_call_started)
	sec.landline.call_finished.connect(_on_call_finished)
	sec.front_door.lock_changed.connect(_on_front_lock)
	sec.office_door.lock_changed.connect(_on_office_lock)
	return self

## SecurityBeats hands over here once Dina has told Jamie to lock up.
func begin() -> void:
	if not director._once("threat_begin"):
		return
	director._set_step(StoryDirector.Step.THREAT)
	active = true
	ended = ""
	threat_time = 0.0
	director.clock.advance_to(0, 31)
	game.tasks.add_task("closing", "Get through the night", [
		{"id": "lock_front", "text": "Lock the front door"},
		{"id": "call", "text": "Call the police (office phone)"}])
	if sec.front_door.locked:
		game.tasks.complete_objective("closing", "lock_front")
	director._record("threat_begin")
	game.save_checkpoint("closing_time")
	director._later(entry_delay, leon_returns)

func leon_returns() -> void:
	if ended != "" or not director._once("leon_returns"):
		return
	director._record("leon_returns")
	if not director.spawn_enabled:
		return
	stalker = sec.spawn_stalker()
	stalker.caught.connect(_on_caught)
	await stalker.enter_building()
	if ended != "" or not is_instance_valid(stalker):
		return
	director._text("dina_9", "Dina", "Was that the back door? Get out the front or lock yourself in. Don't go looking.", 0, 33)
	stalker.begin_hunt()

func _physics_process(delta: float) -> void:
	_flash_sirens(delta)
	if not active or ended != "":
		return
	threat_time += delta
	var player: CharacterBody3D = game.player
	if player.global_position.z > ESCAPE_Z and player.enabled:
		end("escape")
		return
	if police_left >= 0.0:
		police_left -= delta
		if police_left <= 0.0:
			end("secured")
			return
	if threat_time > rescue_after:
		end("secured")  # Dina and the first car turn up regardless: nobody can be stuck in here forever

func in_office() -> bool:
	var p := game.player.global_position
	return p.x > OFFICE_MIN_X and p.z < OFFICE_MAX_Z

func is_secured() -> bool:
	return in_office() and sec.office_door.locked

func _on_front_lock(locked: bool) -> void:
	if locked and active:
		game.tasks.complete_objective("closing", "lock_front")

func _on_office_lock(_locked: bool) -> void:
	pass

func _on_call_started() -> void:
	if not active:
		return
	if is_instance_valid(stalker):
		stalker.hear(Vector3(6.9, 0.0, -4.5), 30.0)

func _on_call_finished() -> void:
	if not active:
		return
	game.tasks.complete_objective("closing", "call")
	police_left = police_eta
	director._record("police_called")
	if is_instance_valid(stalker):
		stalker.hear(Vector3(6.9, 0.0, -4.5), 30.0)

func _on_caught() -> void:
	end("caught")

func end(kind: String) -> void:
	if ended != "":
		return
	ended = kind
	active = false
	director._set_step(StoryDirector.Step.ENDED)
	director.flags["ending"] = kind
	director._record("ending_" + kind)
	game.player.enabled = false
	if game.security.hiding.occupied:
		game.security.hiding.leave()
		game.player.enabled = false
	if kind == "caught":
		if is_instance_valid(stalker):
			stalker.stand_down()
	elif kind == "secured":
		_start_sirens()
		if is_instance_valid(stalker):
			stalker.stand_down()
	elif kind == "escape":
		_start_sirens(true)
		if is_instance_valid(stalker):
			stalker.stand_down()
	ending.emit(kind)

func _start_sirens(alarm := false) -> void:
	if _siren_tone == null:
		_siren_tone = Tone.player(Tone.stream(720.0, 700, 0.8, 0.3), Vector3(1.7, 2.0, 12.0), 40.0)
		_siren_tone.max_distance = 60.0
		_siren_tone.finished.connect(func(): if ended == "secured" or ended == "escape": _siren_tone.play())
		game.world.add_child(_siren_tone)
		for color in [Color(1.0, 0.1, 0.1), Color(0.15, 0.25, 1.0)]:
			var lamp := OmniLight3D.new()
			lamp.light_color = color
			lamp.omni_range = 9.0
			lamp.light_energy = 0.0
			lamp.position = Vector3(1.7 + (-1.5 if color.r > 0.5 else 1.5), 1.6, 9.5)
			game.world.add_child(lamp)
			siren_lights.append(lamp)
	_siren_tone.play()

func _flash_sirens(delta: float) -> void:
	if siren_lights.is_empty():
		return
	var on := ended == "secured" or ended == "escape"
	_siren_flip += delta
	for i in siren_lights.size():
		var phase := int(_siren_flip * 4.0) % 2
		siren_lights[i].light_energy = (4.0 if (phase == i) else 0.2) if on else 0.0

## Put the shop back to the moment the checkpoint was written. Used for retry and for loading.
func clear_actors() -> void:
	active = false
	ended = ""
	police_left = -1.0
	threat_time = 0.0
	if _siren_tone != null:
		_siren_tone.stop()
	for lamp in siren_lights:
		lamp.light_energy = 0.0
	if is_instance_valid(stalker):
		stalker.queue_free()
	stalker = null
	if is_instance_valid(sec.intruder):
		sec.intruder.queue_free()
	sec.intruder = null
