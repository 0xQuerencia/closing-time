extends Node
## Reproducible real-renderer captures for the M3 shopper models.
const RetroEffect = preload("res://scenes/world/retro_effects.gd")
var world: Node3D
var game: Gameplay
var _viewport: SubViewport
var _camera: Camera3D

func run(market: Node3D) -> void:
	world = market
	game = market.gameplay
	game.dialogue.time_scale_for_tests = 0.08
	_create_capture_view()
	var customer := game.spawn_customer()
	if customer == null:
		push_error("M3 visual capture could not spawn the first customer")
		await world.finish_run(1)
		return
	var browsing := await _wait_until(func():
		return is_instance_valid(customer) and customer.phase == Customer.Phase.BROWSE and Vector2(customer.velocity.x, customer.velocity.z).length() > 0.1 and customer.global_position.z < 2.45
	, 35.0)
	if not browsing:
		push_error("M3 visual capture did not reach the browsing walk")
		await world.finish_run(1)
		return
	_look_from(Vector3(-1.5, 1.62, 5.6), Vector3(-1.5, 0.95, 2.1))
	await _save("m3_customer_browsing")
	var at_checkout := await _wait_until(func():
		return is_instance_valid(customer) and game.checkout.state == Checkout.State.OPEN
	, 45.0)
	if not at_checkout:
		push_error("M3 visual capture did not reach the customer checkout")
		await world.finish_run(1)
		return
	_look_from(Vector3(-3.5, 1.62, 5.4), customer.global_position + Vector3(0, 0.9, 0))
	await _save("m3_customer_checkout")
	for item in game.checkout.items:
		game.checkout.scan(item)
	game.checkout.take_payment()
	await customer.finished
	print("M3 CUSTOMER CAPTURE COMPLETE: browsing and checkout screenshots saved; sale closed once")
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport.queue_free()
	await get_tree().process_frame
	await world.finish_run(0)

func _create_capture_view() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1600, 900)
	_viewport.positional_shadow_atlas_size = 2048
	_viewport.world_3d = world.get_viewport().world_3d
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	world.add_child(_viewport)
	_viewport.add_child(RetroEffect.new())
	_camera = Camera3D.new()
	_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_camera.fov = 75.0
	_camera.near = 0.055
	_viewport.add_child(_camera)
	_camera.current = true

func _look_from(from: Vector3, target: Vector3) -> void:
	_camera.position = from
	_camera.look_at(target)

func _save(name: String) -> void:
	DirAccess.make_dir_recursive_absolute("res://local/screenshots/m3")
	await RenderingServer.frame_post_draw
	var path := "res://local/screenshots/m3/%s.png" % name
	var error := _viewport.get_texture().get_image().save_png(path)
	print("M3 CUSTOMER CAPTURE ", name, " status=", error, " frame=", _viewport.size)

func _wait_until(condition: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return true
		await get_tree().physics_frame
	return condition.call()
