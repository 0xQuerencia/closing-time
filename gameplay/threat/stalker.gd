class_name Stalker
extends Intruder
## Leon hunting through the shop. He walks the NavGraph, sees in a forward cone, hears running, tries locked doors
## and never teleports. Everything he does is legible: footsteps, a head turn, then a run.
signal state_changed(state: State)
signal caught
enum State { DORMANT, PATROL, INVESTIGATE, CHASE, SEARCH, AT_DOOR, CAUGHT, LEAVING }
const PATROL_SPEED := 1.3
const INVESTIGATE_SPEED := 1.6
const CHASE_SPEED := 2.2
const SIGHT_RANGE := 11.0
const SIGHT_HALF_ANGLE := deg_to_rad(62.0)
const CLOSE_NOTICE := 1.7
const CATCH_DISTANCE := 0.95
const FOUND_HIDING_DISTANCE := 1.5
const LOSE_SIGHT_AFTER := 2.5
const SEARCH_SECONDS := 6.0
const RUN_NOISE_SPEED := 2.4
const RUN_NOISE_RADIUS := 6.5
const EYE := 1.6
const PATROL_ROUTE: Array[String] = ["hall_office", "hall_stock", "hall_breaker", "shop_se", "front_in", "lane_mid", "lane_counter", "counter_end", "north_mid", "shop_ne"]
var state := State.DORMANT
var graph := NavGraph.new()
var office_door: Door
var last_seen := Vector3.ZERO
var saw_hide := false
var door_rattles := 0
var notice_count := 0
var _patrol_index := 0
var _target := Vector3.ZERO
var _path := PackedVector3Array()
var _repath := 0.0
var _lost := 0.0
var _dwell := 0.0
var _rattle_timer := 0.0
var _noise_timer := 0.0
var _stuck := 0.0
var _last_pos := Vector3.ZERO
var steps_taken := 0

func begin_hunt(start_index := 0) -> void:
	_patrol_index = start_index % PATROL_ROUTE.size()
	_set_state(State.PATROL)
	_goto(graph.point(PATROL_ROUTE[_patrol_index]))

func stand_down() -> void:
	_set_state(State.DORMANT)
	velocity = Vector3.ZERO

func leave_by_rear() -> void:
	_set_state(State.LEAVING)
	velocity = Vector3.ZERO
	await _walk(_route_to_rear())
	await leave_building()

func _route_to_rear() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for p in graph.path(global_position, graph.point("vestibule")):
		out.append(p)
	return out

func _set_state(next: State) -> void:
	if state == next:
		return
	state = next
	_lost = 0.0
	_dwell = 0.0
	state_changed.emit(next)

func _goto(point: Vector3) -> void:
	_target = point
	_path = PackedVector3Array()
	_repath = 0.0

## A sound at `at` that a person within `radius` of it would hear.
func hear(at: Vector3, radius: float) -> void:
	if state in [State.DORMANT, State.CAUGHT, State.LEAVING, State.CHASE]:
		return
	if global_position.distance_to(at) > radius:
		return
	if state == State.AT_DOOR:
		return
	if office_door != null and office_door.locked and at.x > 5.0 and at.z < -2.5:
		_goto(graph.point("hall_office"))
		_set_state(State.AT_DOOR)
		return
	last_seen = at
	_goto(Vector3(at.x, 0.0, at.z))
	_set_state(State.INVESTIGATE)

func player_hid() -> void:
	if state == State.CHASE and _sees_player():
		saw_hide = true

func _physics_process(delta: float) -> void:
	if not inside or state in [State.DORMANT, State.LEAVING]:
		return
	if state == State.CAUGHT:
		_stop(delta)
		return
	_listen(delta)
	if _sees_player():
		last_seen = game.player.global_position
		_lost = 0.0
		if state != State.CHASE:
			notice_count += 1
			_set_state(State.CHASE)
	elif state == State.CHASE and not saw_hide:
		_lost += delta
	match state:
		State.PATROL:
			_patrol(delta)
		State.INVESTIGATE:
			_investigate(delta)
		State.CHASE:
			_chase(delta)
		State.SEARCH:
			_search(delta)
		State.AT_DOOR:
			_at_door(delta)

# --- senses -------------------------------------------------------------------------------------

func _hiding() -> bool:
	return game.security.hiding != null and game.security.hiding.occupied

func _sees_player() -> bool:
	var player := game.player as Node3D
	var to := player.global_position + Vector3(0, 1.1, 0) - (global_position + Vector3(0, EYE, 0))
	var flat := Vector2(to.x, to.z)
	var dist := flat.length()
	if _hiding():
		return saw_hide and dist < 8.0 and _line_clear(to) or dist < FOUND_HIDING_DISTANCE and _line_clear(to)
	if dist > SIGHT_RANGE:
		return false
	var facing := Vector2(-sin(rotation.y), -cos(rotation.y))
	if dist > CLOSE_NOTICE and absf(facing.angle_to(flat)) > SIGHT_HALF_ANGLE:
		return false
	return _line_clear(to)

func _line_clear(to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, EYE, 0), global_position + Vector3(0, EYE, 0) + to)
	query.collision_mask = 1
	query.exclude = [get_rid(), (game.player as CollisionObject3D).get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _listen(delta: float) -> void:
	_noise_timer -= delta
	var player := game.player as CharacterBody3D
	if _noise_timer > 0.0 or _hiding() or not player.enabled:
		return
	var flat := Vector2(player.velocity.x, player.velocity.z).length()
	if flat > RUN_NOISE_SPEED:
		_noise_timer = 0.5
		hear(player.global_position, RUN_NOISE_RADIUS)

# --- behaviours ---------------------------------------------------------------------------------

func _patrol(delta: float) -> void:
	if _dwell > 0.0:
		_dwell -= delta
		_stop(delta)
		_animate_stalk()
		return
	if _walk_step(delta, PATROL_SPEED):
		_dwell = 1.6
		_play_animation("LookAround")
		_open_office_if_peeking()
		_patrol_index = (_patrol_index + 1) % PATROL_ROUTE.size()
		_goto(graph.point(PATROL_ROUTE[_patrol_index]))

func _open_office_if_peeking() -> void:
	if office_door != null and PATROL_ROUTE[_patrol_index] == "hall_office" and not office_door.is_open:
		if office_door.locked:
			office_door.rattle()
			door_rattles += 1
		else:
			office_door.request_open(self)

func _investigate(delta: float) -> void:
	if _walk_step(delta, INVESTIGATE_SPEED):
		_set_state(State.SEARCH)

func _chase(delta: float) -> void:
	var player := game.player as Node3D
	var target := player.global_position if (_sees_player() or saw_hide) else last_seen
	if _hiding() and saw_hide:
		target = game.security.hiding.global_position
	_target = target
	var close := Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z).length() < CATCH_DISTANCE
	if close and _sees_player():
		_set_state(State.CAUGHT)
		caught.emit()
		return
	if _lost > LOSE_SIGHT_AFTER:
		_set_state(State.SEARCH)
		return
	var arrived := _walk_step(delta, CHASE_SPEED)
	if arrived and not _sees_player():
		_set_state(State.SEARCH)

func _search(delta: float) -> void:
	_dwell += delta
	_stop(delta)
	_play_animation("LookAround")
	if _dwell > SEARCH_SECONDS:
		saw_hide = false
		_goto(graph.point(PATROL_ROUTE[_patrol_index]))
		_set_state(State.PATROL)

func _at_door(delta: float) -> void:
	if office_door == null or not office_door.locked:
		_set_state(State.PATROL)
		return
	var door_point := graph.point("hall_office")
	var to_door := Vector3(door_point.x - global_position.x, 0, door_point.z - global_position.z)
	if to_door.length() > 0.3:
		_walk_step(delta, INVESTIGATE_SPEED)
		return
	_stop(delta)
	var face := Vector3(5.0, 0.0, -4.3) - global_position
	rotation.y = rotate_toward(rotation.y, atan2(-face.x, -face.z), 6.0 * delta)
	_rattle_timer -= delta
	if _rattle_timer <= 0.0:
		_rattle_timer = 2.2
		office_door.rattle()
		door_rattles += 1
	_animate_stalk()

# --- movement -----------------------------------------------------------------------------------

## Moves toward the current target along the graph. True once he is there.
func _walk_step(delta: float, speed: float) -> bool:
	var flat_to_target := Vector3(_target.x - global_position.x, 0, _target.z - global_position.z)
	if flat_to_target.length() < 0.35:
		_stop(delta)
		return true
	_repath -= delta
	var direct := _direct_ok(flat_to_target)
	var aim := _target
	if not direct:
		if _path.is_empty() or _repath <= 0.0:
			_path = _trimmed_path()
			_repath = 0.8
		while _path.size() > 0 and Vector3(_path[0].x - global_position.x, 0, _path[0].z - global_position.z).length() < 0.4:
			_path.remove_at(0)
		if _path.size() > 0:
			aim = _path[0]
	_open_doors_ahead(aim)
	_steer(aim, speed, delta)
	_check_stuck(delta)
	return false

func _trimmed_path() -> PackedVector3Array:
	var nodes := graph.path(global_position, _target)
	while nodes.size() >= 2 and global_position.distance_to(nodes[1]) < nodes[0].distance_to(nodes[1]):
		nodes.remove_at(0)
	return nodes

func _direct_ok(flat_to_target: Vector3) -> bool:
	if flat_to_target.length() > 6.0:
		return false
	for height in [0.35, 1.0]:
		var from := global_position + Vector3(0, height, 0)
		var query := PhysicsRayQueryParameters3D.create(from, from + flat_to_target)
		query.collision_mask = 1
		query.exclude = [get_rid(), (game.player as CollisionObject3D).get_rid()]
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			return false
	return true

func _open_doors_ahead(aim: Vector3) -> void:
	if office_door == null or office_door.locked or office_door.is_open:
		return
	if global_position.distance_to(Vector3(5.0, 0.0, -4.3)) < 1.7 and aim.x > 4.6 and aim.z < -3.5:
		office_door.request_open(self)

func _steer(aim: Vector3, speed: float, delta: float) -> void:
	var dir := Vector3(aim.x - global_position.x, 0, aim.z - global_position.z)
	if dir.length() < 0.01:
		_stop(delta)
		return
	dir = dir.normalized()
	var turn_rate := 7.0 if state == State.CHASE else 3.4
	rotation.y = rotate_toward(rotation.y, atan2(-dir.x, -dir.z), turn_rate * delta)
	var turn := absf(angle_difference(rotation.y, atan2(-dir.x, -dir.z)))
	var pace := speed * lerpf(1.0, 0.35, clampf(turn / PI, 0.0, 1.0))
	var horizontal := Vector2(velocity.x, velocity.z).move_toward(Vector2(dir.x, dir.z) * pace, 7.0 * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.y
	_gravity(delta)
	move_and_slide()
	_footsteps(delta)
	_animate_stalk()

## Heavier work boots than the shoppers', quicker when he runs. It is the main way to know where he is.
func _footsteps(delta: float) -> void:
	var running := Vector2(get_real_velocity().x, get_real_velocity().z).length() > 1.9
	if _step_sound(delta * (1.0 if not running else 0.75), -11.0 if running else -14.0):
		steps_taken += 1
		_feet.max_distance = 22.0
		_feet.pitch_scale *= 0.88  # a bigger man in boots

func _stop(delta: float) -> void:
	var horizontal := Vector2(velocity.x, velocity.z).move_toward(Vector2.ZERO, 9.0 * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.y
	_gravity(delta)
	move_and_slide()

func _gravity(delta: float) -> void:
	velocity.y = -0.1 if is_on_floor() else velocity.y - GRAVITY * delta

func _check_stuck(delta: float) -> void:
	if global_position.distance_to(_last_pos) < 0.2 * delta:
		_stuck += delta
	else:
		_stuck = 0.0
	_last_pos = global_position
	if _stuck > 2.5:
		_stuck = 0.0
		_path = PackedVector3Array()
		_repath = 0.0

## His head leads the hunt: locked on Jamie once seen, on the noise he is walking to, on the handle he is trying.
func _gaze_point(delta: float) -> Variant:
	match state:
		State.CHASE, State.CAUGHT:
			return _player_eye()
		State.INVESTIGATE:
			return last_seen + Vector3(0, 1.1, 0)
		State.AT_DOOR:
			return Vector3(5.0, 1.45, -4.3)
	return super(delta)

func _animate_stalk() -> void:
	if _animation_player == null:
		return
	var speed := Vector2(get_real_velocity().x, get_real_velocity().z).length()
	if speed > 0.15:
		var clip: StringName = &"Run" if state == State.CHASE and _animation_player.has_animation(&"Run") else &"Walk"
		_play_animation(clip)
		_animation_player.speed_scale = clampf(speed / (2.4 if clip == &"Run" else WALK_CLIP_SPEED), 0.3, 1.2)
	elif state != State.PATROL or _dwell <= 0.0:
		_play_animation("Idle")
