extends SceneTree

const APARTMENT := "res://scenes/apartment/apartment.tscn"
const ROAD := "res://scenes/route9/route9.tscn"
const MARKET := "res://scenes/world/market_root.tscn"
var failures := 0
var drive_checkpoint: Dictionary

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(110.0).timeout.connect(func(): printerr("Opening test timed out"); quit(1))
	OpeningCheckpoint.erase()
	set_meta("closing_time_epilogue","evidence_preserved")
	change_scene_to_file(APARTMENT)
	await scene_changed
	var room := current_scene
	room.player.require_mouse_capture = false
	await _use_at(room,"epilogue_paper",Vector3(.88,.03,-2.53))
	check(room.narration.text.contains("missing employee inquiry"),"Epilogue newspaper remains readable")
	await _use_at(room,"epilogue_phone",Vector3(.48,.03,-2.53))
	check(room.narration.text.contains("Breakfast"),"Epilogue phone remains readable")

	change_scene_to_file(MARKET)
	await scene_changed
	var title: FlowUI = current_scene.gameplay.flow
	var original_size := root.size
	root.size = Vector2i(640, 360)
	await process_frame
	await process_frame
	var title_rect := title._title.get_global_rect()
	var menu_rect := title._buttons.get_global_rect()
	check(title_rect.position.y >= 0.0 and menu_rect.end.y <= root.get_visible_rect().size.y,
		"Title and menu fit at 640 by 360")
	root.size = original_size
	check(title.mode == "title" and title.press("start"), "New Game uses the normal title screen")
	await scene_changed
	room = current_scene
	check(room.player.position.is_equal_approx(Vector3(-1.6,.05,2.4)), "Original apartment spawn")
	var furniture := room.get_node("Furniture and fittings") as MeshInstance3D
	var material := furniture.get_active_material(0) as StandardMaterial3D
	var rug := room.get_node("Patterned bedside rug") as MeshInstance3D
	check(material.albedo_texture.resource_path.ends_with("apartment_night_atlas.png") and
		(rug.get_active_material(0) as StandardMaterial3D).albedo_texture.resource_path.ends_with("apartment_night_rug.png"),
		"Opening contains the new authored apartment materials")
	var work_light := room.get_node("Lamp pool over shift note") as OmniLight3D
	var window_fill := room.get_node("Night window fill") as OmniLight3D
	check(not work_light.shadow_enabled and not window_fill.shadow_enabled and
		work_light.light_color.r > work_light.light_color.b and window_fill.light_color.b > window_fill.light_color.r,
		"Warm practical light and cool window fill keep independent low-cost pools")

	check(is_instance_valid(room.prologue), "New Game opens the prologue")
	_key(KEY_ESCAPE, true)
	await process_frame
	_key(KEY_ESCAPE, false)
	await process_frame
	check(not is_instance_valid(room.prologue), "Escape skips the prologue")
	room.player.require_mouse_capture = false
	_key(KEY_D,true)
	for frame in 60:
		await physics_frame
	_key(KEY_D,false)
	_key(KEY_W,true)
	for frame in 139:
		await physics_frame
	_key(KEY_W,false)
	check(room.player.position.z < -1.75 and room.player.is_on_floor(),"Walk from spawn toward desk on original floor")
	await _use_at(room,"apartment_exit",Vector3(.65,.03,3.10))
	check(not room.leaving and room.narration.text.contains("still need"),"Exit requires phone, keys and vest")
	await _use_at(room,"shift_read",Vector3(.48,.03,-2.53))
	check(room.progress.events.has("shift_read") and room.narration.text.contains("Dina"),"Read Dina's phone through the interaction ray")
	await _use_at(room,"rent_notice",Vector3(.88,.03,-2.53))
	await _use_at(room,"kay_photo",Vector3(1.25,.03,-2.80))
	check(room.progress.events.has("rent_notice") and room.progress.events.has("kay_photo"),"Read rent notice and Kay photo")
	await _use_at(room,"keys_taken",Vector3(-2.63,.03,2.43))
	await _use_at(room,"vest_taken",Vector3(-2.15,.03,2.82))
	for id in ["keys_taken","vest_taken"]:
		check(room.progress.events.has(id) and not room.targets[id].node.visible and room.targets[id].node.collision_layer == 0,"Pick up and remove collision for " + id)

	var saved := OpeningCheckpoint.read()
	check(saved.get("chapter") == "apartment","Apartment checkpoint written")
	OpeningCheckpoint.resume(self,saved)
	await scene_changed
	room = current_scene
	for id in ["keys_taken","vest_taken"]:
		check(not room.targets[id].node.visible and room.targets[id].node.collision_layer == 0,"Resume preserves pickup " + id)
	await _use_at(room,"apartment_exit",Vector3(.65,.03,3.10))
	if current_scene == null or current_scene.scene_file_path == APARTMENT:
		await scene_changed
	check(current_scene.scene_file_path == ROAD and current_scene.progress.events.has("drive_started"),"Apartment exit starts Route 9 with apartment progress")
	if "--apartment-only" not in OS.get_cmdline_user_args():
		drive_checkpoint = OpeningCheckpoint.read()
		await _drive(current_scene)
		await _skip_drive()
	print("OPENING ART TESTS COMPLETE failures=",failures)
	if current_scene.has_method("finish_run"):
		await current_scene.finish_run(1 if failures else 0)
	else:
		quit(1 if failures else 0)

func _drive(road: Node) -> void:
	var roadside: Node3D = road.get_node("Route 9 roadside")
	check(roadside.get_child_count() > 20 and roadside.find_children("*","MultiMeshInstance3D",true,false).size() > 20,
		"Route surfaces and batched roadside trees are present in the driving scene")
	var wagon: Node3D = road.car.get_node("Route9Wagon")
	var steering: Node3D = road.wheel
	var camera := root.get_camera_3d()
	check(camera.position.is_equal_approx(Vector3(-.38,1.24,.22)) and is_equal_approx(camera.fov,75.0),
		"Driver camera retains the original mount and FOV")
	check(wagon.has_node("SpeedNeedle") and wagon.has_node("SteeringWheel"),"Authored cockpit is active")
	var tire: MeshInstance3D
	var tire_nodes := wagon.find_children("RoadWheel*", "MeshInstance3D",false,false)
	check(tire_nodes.size() == 4,"Four wagon wheels")
	if tire_nodes.size() == 4:
		tire = tire_nodes[0]
		check(tire_nodes.all(func(wheel): return wheel.mesh == tire.mesh),"Wheels share one mesh resource")

	_key(KEY_R,true)
	await process_frame
	_key(KEY_R,false)
	_key(KEY_T,true)
	await process_frame
	_key(KEY_T,false)
	await process_frame
	check(road.radio_on and road.progress.events.has("radio_tuned") and not road.wipers_on,"Radio and wiper controls")
	check(is_equal_approx(road.wiper.rotation.z,road.WIPER_PARK),"Switched-off wiper parks at the cowl")
	var needle_at_rest: float = road.speed_needle.rotation.z
	_key(KEY_T,true)
	await process_frame
	_key(KEY_T,false)
	_key(KEY_W,true)
	_key(KEY_D,true)
	var furthest_sweep: float = road.WIPER_PARK
	for i in 120:
		await process_frame
		furthest_sweep = minf(furthest_sweep,road.wiper.rotation.z)
	_key(KEY_D,false)
	check(road.speed > 7.0 and road.lateral > 1.0 and steering.rotation.z < -.3,"Accelerator and steering move the wagon")
	check(furthest_sweep < -1.0 and is_equal_approx(road.wiper.rotation.z,road.WIPER_PARK),
		"Live wiper sweeps the glass and rests between passes")
	check(absf(road.speed_needle.rotation.z-needle_at_rest) > .5,"Real instrument needle responds to acceleration")
	_key(KEY_A,true)
	for i in 42:
		await process_frame
	_key(KEY_A,false)
	check(road.lateral < 1.0,"Steering can return the wagon across the lane")
	while road.travelled < 131.0:
		await process_frame
	_key(KEY_E,true)
	await process_frame
	_key(KEY_E,false)
	check(road.progress.events.has("bypass_sign"),"Bypass sign remains readable while driving")
	var route_save := OpeningCheckpoint.read()
	check(route_save.get("chapter") == "route9" and route_save.events.has("drive_started"),"Driving writes the Route 9 checkpoint")
	while road.travelled < road.LENGTH:
		await process_frame
	_key(KEY_W,false)
	_key(KEY_S,true)
	await scene_changed
	_key(KEY_S,false)
	var market := current_scene
	await physics_frame
	check(market.scene_file_path.ends_with("market_root.tscn"),"Driving the entire route and braking enters the market")
	var parked := market.get_node("OriginalExterior/Route9Wagon")
	check(parked.scene_file_path == "res://assets/models/opening/route9_wagon.glb"
		and parked.position.is_equal_approx(Vector3(-4.9,-.12,13.0)),"Arrival reuses the exact GLB at the established lot position")
	var shift = market.gameplay.director.production
	check(shift != null and shift.progress.current_id() == "handover"
		and shift.progress.events.has("shift_read") and shift.progress.events.has("market_arrived")
		and shift.progress.events.has("bypass_sign"),"Arrival forwards required and optional progress to handover")
	var market_save := SaveGame.read()
	check(market_save.get("checkpoint") == "shift_start" and market_save.production.chapter == "handover"
		and market_save.production.events.has("market_arrived") and OpeningCheckpoint.read().is_empty(),
		"Market save takes over from the opening checkpoint at handover")
	check(market.player.position.distance_to(Vector3(1.85,-.1,12.55)) < .05,"Original market arrival spawn")
	market.player.require_mouse_capture = false
	_key(KEY_W,true)
	for i in 160:
		await physics_frame
	_key(KEY_W,false)
	check(market.player.position.z < 8.0,"Walk from the parked wagon up the curb ramp")
	var door: Node3D = market.gameplay.security.front_door
	_aim(market.player,door.handle.global_position)
	await physics_frame
	await physics_frame
	check(market.gameplay.interactor.interact(),"Use the original storefront door through the player ray")
	for i in 80:
		await physics_frame
	check(door.is_fully_open(),"Storefront door clears the entrance")
	market.player.rotation.y = 0
	_key(KEY_W,true)
	for i in 120:
		await physics_frame
	_key(KEY_W,false)
	check(market.player.position.z < 5.0,"Walk through the storefront entrance")

func _skip_drive() -> void:
	OpeningCheckpoint.resume(self, drive_checkpoint)
	await scene_changed
	var road := current_scene
	check(road.scene_file_path == ROAD and road.travelled == 0.0 and road.skip.visible, "Skip is available at the start of Route 9")
	_key(KEY_ENTER, true)
	await process_frame
	_key(KEY_ENTER, false)
	if current_scene == null or current_scene.scene_file_path == ROAD:
		await scene_changed
	await physics_frame
	var shift: ProductionShift = current_scene.gameplay.director.production
	check(shift != null and shift.progress.current_id() == "handover"
		and shift.progress.events.has("drive_started") and shift.progress.events.has("market_arrived")
		and shift.progress.events.has("shift_read"), "Skipping joins the same handover with required progress")

func _use_at(room: Node, id: String, position: Vector3) -> void:
	var player: CharacterBody3D = room.player
	player.position = position
	player.velocity = Vector3.ZERO
	_aim(player,room.targets[id].node.global_position)
	await physics_frame
	await physics_frame
	await process_frame
	check(room.selected == id,"Ray selects " + id + " (actual " + room.selected + ")")
	_key(KEY_E,true)
	await process_frame
	_key(KEY_E,false)

func _aim(player: CharacterBody3D, point: Vector3) -> void:
	var direction: Vector3 = point - player.camera.global_position
	player.rotation.y = atan2(-direction.x,-direction.z)
	player.camera.rotation.x = atan2(direction.y,Vector2(direction.x,direction.z).length())

func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ",label)
	else:
		failures += 1
		printerr("FAIL ",label)
