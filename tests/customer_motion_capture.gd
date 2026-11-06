extends "res://tests/visual_capture_m3.gd"
## Real engine frames, fixed-step playback; never substitutes a staged animation for navigation.
func run(market: Node3D) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	world = market
	game = market.gameplay
	game.dialogue.time_scale_for_tests = 0.08
	_create_capture_view()
	_viewport.size = Vector2i(960, 540)
	var label := "after" if "--after" in OS.get_cmdline_user_args() else "before"
	var directory := "res://local/customer-motion/" + label
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--art-comparison="):
			var variant := argument.trim_prefix("--art-comparison=")
			if variant not in ["cordatix", "vinrax"]:
				push_error("Unknown art comparison variant")
				await world.finish_run(1)
				return
			directory = "res://local/m32/" + variant
	DirAccess.make_dir_recursive_absolute(directory)
	for file in DirAccess.get_files_at(directory):
		if file.begins_with("frame_") and file.ends_with(".jpg"):
			DirAccess.remove_absolute(directory + "/" + file)
	var frame := 0
	for visitor in range(2):
		var customer := game.spawn_customer()
		var age := 0.0
		var paid := false
		var checkout_age := 0.0
		var saved := {}
		while is_instance_valid(customer) and age < 90.0:
			var target: Vector3 = customer.global_position + Vector3(0, 0.95, 0)
			var camera_position := Vector3(-0.4, 1.62, 5.7)
			if customer.phase >= Customer.Phase.QUEUE:
				camera_position = Vector3(-3.3, 1.62, 5.5)
			_look_from(camera_position, target)
			await RenderingServer.frame_post_draw
			var image := _viewport.get_texture().get_image()
			image.save_jpg(directory + "/frame_%05d.jpg" % frame, 0.88)
			frame += 1
			var shot := "c%d_%s" % [visitor + 1, Customer.Phase.keys()[customer.phase].to_lower()]
			if not saved.has(shot) and age > 0.7:
				image.save_png(directory + "/" + shot + ".png")
				saved[shot] = true
			if game.checkout.state == Checkout.State.OPEN:
				checkout_age += get_process_delta_time()
			if checkout_age > 3.0 and not paid:
				for item in game.checkout.items:
					if not item.scanned:
						game.checkout.scan(item)
				# Ben's scripted first card attempt declines; keep retrying until the sale
				# actually closes so this capture records his complete visit and exit.
				paid = game.checkout.take_payment()
			age += get_process_delta_time()
			await get_tree().process_frame
		if is_instance_valid(customer):
			push_error("Customer recording timed out")
			await world.finish_run(1)
			return
	var metadata := FileAccess.open(directory + "/capture.json", FileAccess.WRITE)
	metadata.store_string(JSON.stringify({"label": label, "customer_1_art": "cordatix" if "--customer-art=cordatix" in OS.get_cmdline_user_args() else "vinrax", "frames": frame, "playback_fps": 15, "simulation_fps": 30, "resolution": str(_viewport.size), "renderer": RenderingServer.get_current_rendering_method(), "gpu": RenderingServer.get_video_adapter_name(), "note": "Actual engine renders of two customer visits. Capture samples every second fixed simulation frame. Automated scan/payment; no audio. Not a performance benchmark."}, "\t"))
	print("CUSTOMER MOTION CAPTURE COMPLETE ", label, " frames=", frame, " both sales and exits complete")
	await world.finish_run(0)
