class_name Intruder
extends Customer
## Leon at the rear of the building. Scripted movement only: he walks, he stops, he looks. He never reaches for the player.
signal arrived_inside
signal left_building
const OUTSIDE := Vector3(4.25, 0.0, -8.4)
const THRESHOLD := Vector3(4.25, 0.0, -6.6)
const VESTIBULE := Vector3(4.2, 0.0, -4.95)
const CORRIDOR_WALK: Array[Vector3] = [Vector3(4.28, 0, -3.6), Vector3(4.2, 0, -2.2), Vector3(4.26, 0, -0.9)]
const SPOOK_DISTANCE := 3.2
var rear_door: Door
var spooked := false
var inside := false
var leaving := false
var _stare: Variant = null

func prepare(rear: Door) -> Intruder:
	rear_door = rear
	phase = Phase.ARRIVE
	talk.available = false
	talk.enabled = false
	return self

## The key turns, the door opens, he steps in and stops just inside.
func enter_building() -> void:
	global_position = OUTSIDE
	rotation.y = 0.0
	if rear_door.locked:
		rear_door.set_locked(false)  # he has the spare key from the hook
	await _wait(0.9)
	rear_door.request_open(self)
	await _wait(1.0)
	await _walk([THRESHOLD, Vector3(4.25, 0, -5.55), VESTIBULE])
	rear_door.request_close()  # pulled shut behind him
	inside = true
	arrived_inside.emit()

## Stands in the dark corridor, head turning, until the player gets too close.
func wait_in_vestibule(seconds: float) -> void:
	_play_animation("LookAround")
	var left := seconds
	while left > 0.0 and not spooked:
		await get_tree().physics_frame
		left -= get_physics_process_delta_time()
		if _player_flat_distance() < SPOOK_DISTANCE and not game.security.cctv.viewing:  # sitting at the monitor, you are not near him
			spooked = true

func _player_flat_distance() -> float:
	var offset: Vector3 = game.player.global_position - global_position
	offset.y = 0.0
	return offset.length()

## Down the hall toward the camera, a long look into it, then back out.
func walk_to_camera(camera_point: Vector3) -> void:
	await _walk(CORRIDOR_WALK)
	await _face(camera_point)
	_play_animation("Idle")
	_stare = camera_point + Vector3(0, 1.6, 0)  # stands still and looks straight up into the lens
	await _wait(2.6)
	_stare = null

## He is not here to talk to anyone: his head only goes where the scene sends it.
func _gaze_point(_delta: float) -> Variant:
	return _stare

func leave_building() -> void:
	leaving = true
	var back: Array[Vector3] = [Vector3(4.25, 0, -5.4), THRESHOLD, OUTSIDE]
	rear_door.request_open(self)
	await _wait(0.9)
	await _walk(back)
	rear_door.request_close()
	inside = false
	left_building.emit()
	await _wait(1.0)
	queue_free()
