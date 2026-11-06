class_name Customer
extends CharacterBody3D
## Shopper driven by authored waypoints: ARRIVE -> BROWSE -> QUEUE -> TRANSACTION -> LEAVE.
enum Phase { ARRIVE, BROWSE, QUEUE, TRANSACTION, LEAVE, GONE }
signal phase_changed(phase: Phase)
signal finished(customer: Customer)
const SPEED := 1.4
const ACCELERATION := 1.8
const BRAKING := 2.8
const TURN_SPEED := 2.6
const WALK_CLIP_SPEED := 1.3
const GRAVITY := 18.0
const YIELD_DIST := 0.85
const EXCUSE_AFTER := 5.0
var phase := Phase.ARRIVE
var profile: Dictionary
var game: Gameplay
var impatience_delay := 22.0
var held_product: Product
var talk: TalkInteractable
var _hand: Marker3D
var _carry: CarryPose
var _animation_player: AnimationPlayer
var _current_animation: StringName
var _idle_time := 0.0
var _talk_used := false
var _excused := false
var _look: HeadLook
var _rng := RandomNumberGenerator.new()
var _gaze_clock := 0.0
var _glancing := false
var _glance_point := Vector3.ZERO
var _passing_cooldown := 0.0
var _passing_left := 0.0
var _gesture: StringName
var _gesture_left := 0.0
const GLANCE_SPOTS := [Vector3(-5.6, 1.0, 4.3), Vector3(-4.2, 1.0, 4.4), Vector3(-6.5, 1.4, 1.2), Vector3(1.7, 1.4, 5.0)]
const BACK_OF_STORE := Vector3(4.2, 1.5, -3.0)
const IDLE_CLIPS := [&"Idle", &"IdleShift", &"IdleWait", &"CounterIdle"]
const GAZE_BLOCKING_CLIPS := [&"LookAround", &"LookBehind", &"TurnLeft", &"TurnRight", &"Startle", &"ShakeHead", &"Nod"]

func setup(owner_game: Gameplay, customer_profile: Dictionary) -> Customer:
	game = owner_game
	profile = customer_profile
	name = "Customer_" + profile.id
	collision_layer = 4
	collision_mask = 1
	add_to_group("customers")
	if String(profile.get("id", "")).begins_with("leon"):
		add_to_group("leon_presence")
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
	_rng.seed = hash(profile.get("id", name))
	_gaze_clock = _rng.randf_range(2.0, 4.0)
	game.dialogue.line_shown.connect(_on_line_shown)
	return self

const HAND_RIGS := [
	{"hand": "hand_right", "upper": "upper_arm_right", "lower": "forearm_right", "offset": Vector3(0, 0.05, 0), "tilt": Vector3(PI, 0, 0),
	"upper_axis": Vector3.RIGHT, "lower_axis": Vector3.RIGHT, "upper_angle": 0.0, "lower_angle": 1.1},
	{"hand": "RightHand", "upper": "RightUpperArm", "lower": "RightLowerArm", "offset": Vector3(0, 0.05, 0), "tilt": Vector3(PI / 2, 0, 0),
	"upper_axis": Vector3.BACK, "lower_axis": Vector3.BACK, "upper_angle": 0.0, "lower_angle": -1.1}]
const MODELS := {
	"vinrax": "res://assets/models/characters/vinrax/casual_male.glb",
	"young_man": "res://assets/models/characters/young_man.glb",
	"office_worker": "res://assets/models/characters/office_worker.glb"}
const OUTFITS := {
	"leon_jacket": "res://assets/models/characters/vinrax/casual_male_leon_jacket.png",
	"leon_overshirt": "res://assets/models/characters/vinrax/casual_male_leon_overshirt.png"}

func _build_body() -> void:
	var model_path: String = MODELS.get(profile.get("model", "vinrax"), MODELS.vinrax)
	var model_scene := load(model_path) as PackedScene
	if model_scene == null:
		push_error("Customer visual model failed to load: " + model_path)
		return
	var model := model_scene.instantiate()
	model.name = "CustomerVisual"
	if profile.has("outfit"):
		_apply_outfit(model, OUTFITS[profile.outfit])
	if profile.get("cap", false):
		_attach_cap(model)
	# These authored models face +Z; the store's customer paths use Godot's -Z forward.
	model.rotation.y = PI
	add_child(model)
	var animation_players := model.find_children("*", "AnimationPlayer", true, false)
	if not animation_players.is_empty():
		_animation_player = animation_players[0] as AnimationPlayer
		var library := _animation_player.get_animation_library("").duplicate(true) as AnimationLibrary
		_animation_player.remove_animation_library("")
		_animation_player.add_animation_library("", library)
		for clip_name in _animation_player.get_animation_list():
			var clip := _animation_player.get_animation(clip_name)
			if clip_name in ["Idle", "IdleShift", "IdleWait", "CounterIdle", "LookAround", "Listen", "Talk", "Walk", "Stroll", "Run", "Flee"]:
				clip.loop_mode = Animation.LOOP_LINEAR
			# Smooth the sampler's stepped keys without changing its authored poses.
			for track in range(clip.get_track_count()):
				clip.track_set_interpolation_type(track, Animation.INTERPOLATION_LINEAR)
		_play_animation("Idle")
	_hand = Marker3D.new()
	_hand.position = Vector3(0.3, 1.05, -0.12)
	add_child(_hand)
	_rig_hand(model)
	_rig_head(model)

## Neck and head follow whatever this person is paying attention to.
func _rig_head(model: Node) -> void:
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return
	var skeleton := skeletons[0] as Skeleton3D
	var bones := HeadLook.bones_for(skeleton)
	if bones.is_empty():
		return
	_look = HeadLook.new()
	_look.neck_bone = bones[0]
	_look.head_bone = bones[1]
	skeleton.add_child(_look)

## Hold items in the right hand: ride the hand bone so the arm swing carries them, and bend the elbow.
func _rig_hand(model: Node) -> void:
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return
	var skeleton := skeletons[0] as Skeleton3D
	var rig: Dictionary = {}
	for candidate in HAND_RIGS:
		if skeleton.find_bone(candidate.hand) >= 0:
			rig = candidate
			break
	if rig.is_empty():
		return
	var attach := BoneAttachment3D.new()
	attach.bone_name = rig.hand
	skeleton.add_child(attach)
	_hand.reparent(attach, false)
	_hand.position = rig.offset
	_hand.rotation = rig.tilt
	_carry = CarryPose.new()
	_carry.upper_bone = rig.upper
	_carry.lower_bone = rig.lower
	_carry.upper_axis = rig.upper_axis
	_carry.lower_axis = rig.lower_axis
	_carry.upper_angle = rig.upper_angle
	_carry.lower_angle = rig.lower_angle
	skeleton.add_child(_carry)

## Outfit variant of the shared texture (same UVs, only the clothing recoloured).
func _apply_outfit(model: Node, texture_path: String) -> void:
	var texture := load(texture_path) as Texture2D
	if texture == null:
		return
	for mesh_instance in model.find_children("*", "MeshInstance3D", true, false):
		var mi := mesh_instance as MeshInstance3D
		if mi.mesh == null:
			continue
		for surface in mi.mesh.get_surface_count():
			var base := mi.get_active_material(surface) as BaseMaterial3D
			if base == null:
				continue
			var tinted := base.duplicate() as BaseMaterial3D
			tinted.albedo_texture = texture
			mi.set_surface_override_material(surface, tinted)

## Simple low-poly cap on the head bone (Vinrax has none of his own).
func _attach_cap(model: Node) -> void:
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return
	var skeleton := skeletons[0] as Skeleton3D
	var attach := BoneAttachment3D.new()
	attach.bone_name = "head" if skeleton.find_bone("head") >= 0 else "Head"
	skeleton.add_child(attach)
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.2, 0.22, 0.2)
	cloth.roughness = 0.9
	var crown := MeshInstance3D.new()
	var dome := SphereMesh.new()
	dome.radius = 0.112
	dome.height = 0.16
	dome.is_hemisphere = true
	crown.mesh = dome
	crown.material_override = cloth
	crown.position = Vector3(0, 0.082, -0.012)
	attach.add_child(crown)
	var brim := MeshInstance3D.new()
	var brim_mesh := BoxMesh.new()
	brim_mesh.size = Vector3(0.17, 0.01, 0.085)
	brim.mesh = brim_mesh
	brim.material_override = cloth
	brim.position = Vector3(0, 0.1, 0.1)
	brim.rotation.x = 0.18
	attach.add_child(brim)

func _set_phase(next: Phase) -> void:
	phase = next
	_idle_time = 0.0
	phase_changed.emit(next)
	if is_zero_approx(velocity.x) and is_zero_approx(velocity.z):
		_animate()

## Full visit. Completion of the sale is awaited, never timed out.
func run() -> void:
	var route: Dictionary = profile.route
	_set_phase(Phase.ARRIVE)
	await _walk(route.arrive)
	_set_phase(Phase.BROWSE)
	await _walk(route.browse)
	await _face(global_position + profile.get("browse_face", Vector3(-1, 0, 0)))
	await _wait(float(profile.get("browse_pause", 1.4)))
	if profile.get("second_look", false):
		# A normal shopper taking a second look at the aisle behind him.
		await _face(global_position + Vector3(0, 0, 1.0))
		await _wait(0.85)
		await _face(global_position + profile.get("browse_face", Vector3(-1, 0, 0)))
	var basket: Array[Product] = []
	for item_id in profile.items:
		basket.append(game.spawn_product(item_id, null))
	held_product = basket[0]
	held_product.attach_to(_hand, Vector3.ZERO)
	await _wait(0.6)
	_set_phase(Phase.QUEUE)
	await _walk(route.queue)
	await _face(Vector3(route.queue.back().x, 0, 4.5))
	await _wait(0.4)
	_set_phase(Phase.TRANSACTION)
	var checkout := game.checkout
	while not checkout.open_sale(self):
		await _wait(0.5)  # an earlier sale is still closing
	held_product = null
	talk.available = true
	for slot in basket.size():
		basket[slot].place_at(checkout.drop_point(slot), 0.0)
		await _wait(0.35)
	checkout.payment_failed.connect(_on_reader_failed)
	if not game.dialogue.is_active():  # the player already started talking: don't talk over them
		game.dialogue.start(profile.id + "_greet")
	var waited := 0.0
	var nagged := false
	while checkout.state != Checkout.State.PAID:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
		_idle_time += get_physics_process_delta_time()
		_animate()
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
	checkout.payment_failed.disconnect(_on_reader_failed)
	await _say(profile.id + "_thanks")
	checkout.close_sale()
	_set_phase(Phase.LEAVE)
	await _walk(route.leave)
	if route.has("car"):  # walks off to a parked car and drives away
		await _walk(route.car)
	_set_phase(Phase.GONE)
	finished.emit(self)
	queue_free()

func _on_reader_failed(_remaining: int) -> void:
	if game.dialogue.has_conversation(profile.id + "_reader"):
		game.dialogue.start(profile.id + "_reader")

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
		_idle_time += get_physics_process_delta_time()
		_animate()

func _walk(points: Array) -> void:
	for index in range(points.size()):
		await _walk_to(points[index], index == points.size() - 1)
	velocity = Vector3.ZERO
	_animate()

func _walk_to(target: Vector3, final_point: bool = true) -> void:
	var start := Vector3(target.x - global_position.x, 0, target.z - global_position.z)
	if start.length() > 0.3 and Vector2(velocity.x, velocity.z).length() < 0.25 \
			and absf(angle_difference(rotation.y, atan2(-start.x, -start.z))) > 1.1:
		await _face(target)  # standing still: turn on the spot first instead of sliding round
	var best := INF
	var stalled := 0.0
	var blocked := 0.0
	while is_inside_tree():
		var delta := get_physics_process_delta_time()
		var flat := Vector3(target.x - global_position.x, 0, target.z - global_position.z)
		var remaining := flat.length()
		if remaining < (0.045 if final_point else 0.28):
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
			var desired_yaw := atan2(-dir.x, -dir.z)
			var turn := absf(angle_difference(rotation.y, desired_yaw))
			rotation.y = rotate_toward(rotation.y, desired_yaw, TURN_SPEED * delta)
			var pace := SPEED * (0.82 if phase == Phase.BROWSE else 1.0)
			# Slow before sharp corners and brake only at the end of a route.
			pace *= lerpf(1.0, 0.3, clampf(turn / PI, 0.0, 1.0))
			if final_point:
				pace = minf(pace, sqrt(2.0 * BRAKING * remaining))
			var horizontal := Vector2(velocity.x, velocity.z)
			var desired := Vector2(dir.x, dir.z) * minf(pace, remaining / delta)
			horizontal = horizontal.move_toward(desired, ACCELERATION * delta)
			velocity.x = horizontal.x
			velocity.z = horizontal.y
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

func _player_in_way(dir: Vector3) -> bool:
	var to_player: Vector3 = game.player.global_position - global_position
	to_player.y = 0
	return to_player.length() < YIELD_DIST and to_player.normalized().dot(dir) > 0.5

func _face(point: Vector3) -> void:
	var d := point - global_position
	var yaw := atan2(-d.x, -d.z)
	# Take a short, visible step-turn rather than snapping at the counter.
	var difference := angle_difference(rotation.y, yaw)
	if absf(difference) > 0.15:
		_play_animation("TurnLeft" if difference > 0.0 else "TurnRight")
	while absf(angle_difference(rotation.y, yaw)) > 0.015:
		rotation.y = rotate_toward(rotation.y, yaw, TURN_SPEED * get_physics_process_delta_time())
		await get_tree().physics_frame
	_animate()

func _process(delta: float) -> void:
	if _carry != null:
		_carry.amount = move_toward(_carry.amount, 1.0 if held_product != null else 0.0, delta * 3.0)
	_gesture_left = maxf(0.0, _gesture_left - delta)
	if _look != null:
		var point: Variant = null if _current_animation in GAZE_BLOCKING_CLIPS else _gaze_point(delta)
		_look.has_target = point != null
		if point != null:
			_look.target = point

func _player_eye() -> Vector3:
	return (game.player.camera as Node3D).global_position

## Where this person is looking right now, or null to leave the head to the animation.
func _gaze_point(delta: float) -> Variant:
	var eye := _player_eye()
	var near := Vector2(eye.x - global_position.x, eye.z - global_position.z).length()
	var moving := Vector2(velocity.x, velocity.z).length() > 0.2
	if phase in [Phase.TRANSACTION, Phase.QUEUE] and not moving:
		_gaze_clock -= delta
		if _gaze_clock <= 0.0:
			_glancing = not _glancing
			if _glancing:
				var leon: bool = profile.get("mannerism", "") != ""
				_glance_point = BACK_OF_STORE if leon and _rng.randf() < 0.5 else GLANCE_SPOTS[_rng.randi() % GLANCE_SPOTS.size()]
				_gaze_clock = _rng.randf_range(0.7, 1.5)
			else:
				_gaze_clock = _rng.randf_range(2.5, 5.5)
		if _glancing:
			return _glance_point
		return eye if near < 6.0 else null
	if phase == Phase.BROWSE and not moving:
		return global_position + Vector3(0, 1.05, 0) + (profile.get("browse_face", Vector3(-1, 0, 0)) as Vector3) * 0.8
	# Walking: a short look at the clerk when passing close by, then eyes back on the way ahead.
	_passing_cooldown = maxf(0.0, _passing_cooldown - delta)
	if _passing_left > 0.0:
		_passing_left -= delta
		return eye
	if moving and near < 3.5 and _passing_cooldown <= 0.0:
		_passing_left = _rng.randf_range(1.0, 1.8)
		_passing_cooldown = 9.0
		return eye
	return null

## Talks with a little movement while their own line is up, and listens to Jamie with a nod.
func _on_line_shown(speaker: String, _text: String) -> void:
	if phase != Phase.TRANSACTION or Vector2(velocity.x, velocity.z).length() > 0.1:
		return
	if speaker == profile.get("name", ""):
		_gesture = &"Talk"
		_gesture_left = 1.8
	elif speaker == "Jamie" and _rng.randf() < 0.5:
		_gesture = &"Nod"
		_gesture_left = 1.0

func _animate() -> void:
	if Vector2(velocity.x, velocity.z).length() > 0.1:
		_play_animation("Walk")
		# Use displacement, including collision response, to avoid running feet when blocked.
		var speed := Vector2(get_real_velocity().x, get_real_velocity().z).length()
		if _animation_player != null:
			_animation_player.speed_scale = clampf(speed / WALK_CLIP_SPEED, 0.3, 1.05)
		return
	if _gesture_left > 0.0 and _animation_player != null and _animation_player.has_animation(_gesture):
		_play_animation(_gesture)
		return
	match phase:
		Phase.BROWSE:
			_play_animation("IdleShift")
		Phase.QUEUE:
			_play_animation("IdleWait")
		Phase.TRANSACTION:
			_play_animation(_counter_clip())
		_:
			_play_animation("Idle")

## Standing at the counter: settle, shift weight, and for Leon a look toward the back of the store now and then.
func _counter_clip() -> StringName:
	var mannerism: String = profile.get("mannerism", "")
	if mannerism != "" and int(_idle_time / 6.0) % 3 == 1:
		return StringName(mannerism)
	return &"CounterIdle" if int(_idle_time / 7.0) % 2 == 0 else &"IdleWait"

func _play_animation(clip_name: StringName) -> void:
	if _animation_player == null or not _animation_player.has_animation(clip_name):
		return
	if _current_animation == clip_name and _animation_player.is_playing():
		return
	_current_animation = clip_name
	_animation_player.speed_scale = 1.0
	_animation_player.play(clip_name, 0.24)
	if clip_name in IDLE_CLIPS:
		# Two people never breathe and shift in step.
		_animation_player.seek(_rng.randf() * _animation_player.current_animation_length)
