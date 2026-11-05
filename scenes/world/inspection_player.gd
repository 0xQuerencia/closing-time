extends CharacterBody3D
## Temporary M1 inspection controller; gameplay team replaces this actor.
var camera: Camera3D
var enabled := true
var require_mouse_capture := true
var head_bob := false
var sensitivity := 1.0
var elapsed := 0.0

func _ready() -> void:
	name = "InspectionPlayer"
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.24
	capsule.height = 1.76
	shape.shape = capsule
	shape.position.y = 0.88
	add_child(shape)
	camera = Camera3D.new()
	camera.name = "Eyes"
	camera.position.y = 1.62
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.fov = 75.0 # Fixed horizontal field of view.
	camera.near = 0.055
	add_child(camera)
	camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
		if event.keycode == KEY_B:
			head_bob = not head_bob
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if enabled and event is InputEventMouseMotion and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or not require_mouse_capture):
		rotate_y(-event.relative.x * 0.002 * sensitivity)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * 0.002 * sensitivity, -1.35, 1.35)

func _physics_process(delta: float) -> void:
	if not enabled:
		return
	var move := Vector2.ZERO
	if (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or not require_mouse_capture):
		move = Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	var direction := global_basis * Vector3(move.x, 0, move.y).normalized()
	var speed := 2.8 if Input.is_physical_key_pressed(KEY_SHIFT) else 1.9
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if not is_on_floor():
		velocity.y -= 18 * delta
	else:
		velocity.y = -0.1
	move_and_slide()
	elapsed += delta * move.length()
	camera.position.y = 1.62 + (sin(elapsed * 9) * 0.012 if head_bob else 0.0)
