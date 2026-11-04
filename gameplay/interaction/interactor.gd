class_name Interactor
extends Node
## First-person interaction: raycast from the camera centre, activate, inspect, carry and place.
signal focus_changed(target: Interactable)
signal message(text: String)
signal held_changed(item: Product)
const REACH := 2.2
const HELD_OFFSET := Vector3(0.2, -0.2, -0.45)
const WORLD_AND_INTERACTABLE := 1 | Interactable.LAYER
var camera: Camera3D
var body: CollisionObject3D
var focus: Interactable
var held: Product
var enabled := true
## Callable(position: Vector3, item: Product) -> String; non-empty result vetoes placement.
var placement_validator := Callable()

func setup(player_camera: Camera3D, player_body: CollisionObject3D) -> void:
	camera = player_camera
	body = player_body

func raycast() -> Dictionary:
	if camera == null:
		return {}
	var from := camera.global_position
	var to := from - camera.global_basis.z * REACH
	var query := PhysicsRayQueryParameters3D.create(from, to, WORLD_AND_INTERACTABLE)
	if body:
		query.exclude = [body.get_rid()]
	return camera.get_world_3d().direct_space_state.intersect_ray(query)

func _physics_process(_delta: float) -> void:
	refresh_focus()

func refresh_focus() -> void:
	var target: Interactable = null
	if enabled:
		target = raycast().get("collider") as Interactable
	if target != focus:
		focus = target
		focus_changed.emit(focus)

## Returns {"text": String, "available": bool} for the HUD.
func current_prompt() -> Dictionary:
	if focus == null or not is_instance_valid(focus):
		return {"text": "", "available": false}
	if focus.can_interact(self):
		return {"text": focus.prompt_text(self), "available": true}
	return {"text": focus.blocked_reason(self), "available": false}

func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event.is_action_pressed(GameInput.INTERACT):
		interact()
	elif event.is_action_pressed(GameInput.INSPECT):
		inspect()
	elif event.is_action_pressed(GameInput.DROP):
		place_held()

func interact() -> bool:
	refresh_focus()
	if focus == null:
		return false
	if not focus.can_interact(self):
		var reason := focus.blocked_reason(self)
		if reason != "":
			message.emit(reason)
		return false
	focus.interact(self)
	return true

func inspect() -> bool:
	var subject: Interactable = focus
	if subject == null and held != null:
		subject = held
	if subject == null:
		return false
	var text := subject.inspect(self)
	if text != "":
		message.emit(text)
	return true

func pick_up(item: Product) -> bool:
	if held != null:
		return false
	held = item
	item.attach_to(camera, HELD_OFFSET)
	held_changed.emit(held)
	return true

func place_held() -> bool:
	if held == null:
		return false
	var hit := raycast()
	var collider := hit.get("collider") as Object
	if hit.is_empty() or hit.normal.y < 0.6 or (collider is Interactable and not collider is Product):
		message.emit("Nowhere to put that.")
		return false
	if placement_validator.is_valid():
		var reason: String = placement_validator.call(hit.position, held)
		if reason != "":
			message.emit(reason)
			return false
	var item := held
	held = null
	item.place_at(hit.position, camera.global_rotation.y)
	held_changed.emit(null)
	refresh_focus()
	return true
