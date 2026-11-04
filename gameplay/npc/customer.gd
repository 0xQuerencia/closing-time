class_name Customer
extends CharacterBody3D
## Shopper driven by authored waypoints: ARRIVE -> BROWSE -> QUEUE -> TRANSACTION -> LEAVE.
enum Phase { ARRIVE, BROWSE, QUEUE, TRANSACTION, LEAVE, GONE }
signal phase_changed(phase: Phase)
signal finished(customer: Customer)
const SPEED := 1.3
const GRAVITY := 18.0
const ARRIVE_DIST := 0.12
const YIELD_DIST := 0.85
const EXCUSE_AFTER := 5.0
var phase := Phase.ARRIVE
var profile: Dictionary
var game: Gameplay
var impatience_delay := 22.0
var held_product: Product
var talk: TalkInteractable
var _hand: Marker3D
var _animation_player: AnimationPlayer
var _current_animation: StringName
var _talk_used := false
var _excused := false

func setup(owner_game: Gameplay, customer_profile: Dictionary) -> Customer:
	game = owner_game
	profile = customer_profile
	name = "Customer_" + profile.id
	collision_layer = 4
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.24
	capsule.height = 1.74
	shape.shape = capsule
	shape.position.y = 0.87
	add_child(shape)
	_build_body()
	talk = TalkInteractable.new()
	talk.display_name = "customer"
	var tshape := CollisionShape3D.new()
	var tcap := CapsuleShape3D.new()
	tcap.radius = 0.32
	tcap.height = 1.8
	tshape.shape = tcap
	talk.add_child(tshape)
	talk.position.y = 0.9
	talk.talk_requested.connect(_on_talk)
	add_child(talk)
	add_collision_exception_with(game.player)
	return self

func _build_body() -> void:
	var model_path := "res://assets/models/characters/young_man.glb" if profile.id == "c1" else "res://assets/models/characters/office_worker.glb"
	var model_scene := load(model_path) as PackedScene
	if model_scene == null:
		push_error("Customer visual model failed to load: " + model_path)
		return
	var model := model_scene.instantiate()
	model.name = "CustomerVisual"
	# These authored models face +Z; the store's customer paths use Godot's -Z forward.
	model.rotation.y = PI
	add_child(model)
	var animation_players := model.find_children("*", "AnimationPlayer", true, false)
	if not animation_players.is_empty():
		_animation_player = animation_players[0] as AnimationPlayer
		for clip_name in _animation_player.get_animation_list():
			if clip_name in ["Idle", "IdleShift", "IdleWait", "CounterIdle", "LookAround", "Listen", "Talk", "Walk", "Stroll", "Run", "Flee"]:
				_animation_player.get_animation(clip_name).loop_mode = Animation.LOOP_LINEAR
		_play_animation("Idle")
	_hand = Marker3D.new()
	_hand.position = Vector3(0.3, 1.05, -0.12)
	add_child(_hand)

func _set_phase(next: Phase) -> void:
	phase = next
	phase_changed.emit(next)
	if not is_zero_approx(velocity.x) or not is_zero_approx(velocity.z):
		return
	match phase:
		Phase.BROWSE:
			_play_animation("IdleShift")
		Phase.QUEUE:
			_play_animation("IdleWait")
		Phase.TRANSACTION:
			_play_animation("CounterIdle")
		_:
			_play_animation("Idle")

## Full visit. Completion of the sale is awaited, never timed out.
func run() -> void:
	var route: Dictionary = profile.route
	_set_phase(Phase.ARRIVE)
	await _walk(route.arrive)
	_set_phase(Phase.BROWSE)
	await _walk(route.browse)
	await _wait(1.6)
	held_product = game.spawn_product(profile.product, null)
	held_product.attach_to(_hand, Vector3.ZERO)
	await _wait(0.6)
	_set_phase(Phase.QUEUE)
	await _walk(route.queue)
	_face(Vector3(route.queue.back().x, 0, 4.5))
	await _wait(0.4)
	_set_phase(Phase.TRANSACTION)
	var checkout := game.checkout
	while not checkout.open_sale(self):
		await _wait(0.5)  # an earlier sale is still closing
	var item := held_product
	held_product = null
	item.place_at(checkout.drop_point(0), 0.0)
	talk.available = true
	game.dialogue.start(profile.id + "_greet")
	var waited := 0.0
	var nagged := false
	while checkout.state != Checkout.State.PAID:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
		if not nagged and waited > impatience_delay and not game.dialogue.is_active():
			nagged = true
			game.dialogue.start(profile.id + "_wait")
	talk.available = false
	for bought in checkout.release_items():
		if held_product == null:
			held_product = bought
			bought.attach_to(_hand, Vector3.ZERO)
		else:
			bought.queue_free()
	await _say(profile.id + "_thanks")
	checkout.close_sale()
	_set_phase(Phase.LEAVE)
	await _walk(route.leave)
	_set_phase(Phase.GONE)
	finished.emit(self)
	queue_free()

func _say(conversation: String) -> void:
	if not game.dialogue.start(conversation):
		return
	while true:
		var done: String = await game.dialogue.finished
		if done == conversation:
			return

func _on_talk() -> void:
	if _talk_used:
		return
	_talk_used = true
	game.dialogue.start(profile.id + "_talk")

func _wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await get_tree().physics_frame
		left -= get_physics_process_delta_time()

func _walk(points: Array) -> void:
	for point in points:
		await _walk_to(point)

func _walk_to(target: Vector3) -> void:
	var best := INF
	var stalled := 0.0
	var blocked := 0.0
	while is_inside_tree():
		var delta := get_physics_process_delta_time()
		var flat := Vector3(target.x - global_position.x, 0, target.z - global_position.z)
		var remaining := flat.length()
		if remaining < ARRIVE_DIST:
			break
		var dir := flat / remaining
		var yielding := _player_in_way(dir)
		if yielding:
			# Never walk through the player: wait, and politely ask once.
			velocity.x = 0.0
			velocity.z = 0.0
			blocked += delta
			if blocked > EXCUSE_AFTER and not _excused and not game.dialogue.is_active():
				_excused = true
				game.dialogue.start(profile.id + "_excuse")
		else:
			blocked = 0.0
			velocity.x = dir.x * SPEED
			velocity.z = dir.z * SPEED
			rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), minf(1.0, delta * 8.0))
		velocity.y = -0.1 if is_on_floor() else velocity.y - GRAVITY * delta
		move_and_slide()
		_animate()
		if yielding or remaining < best - 0.01:
			best = minf(best, remaining)
			stalled = 0.0
		else:
			stalled += delta
		if stalled > 12.0:
			push_warning("%s stalled on the way to %s; skipping waypoint" % [name, target])
			break
		await get_tree().physics_frame
	velocity = Vector3.ZERO

func _player_in_way(dir: Vector3) -> bool:
	var to_player: Vector3 = game.player.global_position - global_position
	to_player.y = 0
	return to_player.length() < YIELD_DIST and to_player.normalized().dot(dir) > 0.5

func _face(point: Vector3) -> void:
	var d := point - global_position
	rotation.y = atan2(-d.x, -d.z)

func _animate() -> void:
	if Vector2(velocity.x, velocity.z).length() > 0.1:
		_play_animation("Walk")
		return
	match phase:
		Phase.BROWSE:
			_play_animation("IdleShift")
		Phase.QUEUE:
			_play_animation("IdleWait")
		Phase.TRANSACTION:
			_play_animation("CounterIdle")
		_:
			_play_animation("Idle")

func _play_animation(clip_name: StringName) -> void:
	if _animation_player == null or not _animation_player.has_animation(clip_name):
		return
	if _current_animation == clip_name and _animation_player.is_playing():
		return
	_current_animation = clip_name
	_animation_player.play(clip_name, 0.12)
