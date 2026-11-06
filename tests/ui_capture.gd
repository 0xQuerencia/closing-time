class_name UiCapture
extends Node
## Real-renderer stills of every HUD state. Run: godot --path . --resolution 1280x720 -- --capture-ui [--size=1920x1080]
const OUT := "res://local/screenshots/ui"
var game: Gameplay
var player: CharacterBody3D

func run(market: Node3D) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(OUT)
	game = market.gameplay
	player = market.player
	game.dialogue.time_scale_for_tests = 0.0
	await _frames(40)
	await _stand(Vector3(-1.5, 0.05, 4.6), Vector3(-1.5, 1.4, -3.0))
	await _save("1_explore")
	var cola := game.spawn_product("cola", Vector3(-7.55, 0.955, 4.4))
	await _stand(Vector3(-6.4, 0.05, 5.1), cola.global_position + Vector3(0, 0.1, 0))
	game.interactor.refresh_focus()
	await _frames(10)
	await _save("2_prompt")
	cola.queue_free()
	game.hud._on_line("Ben", "What time do you close?")
	game.hud._on_choices([{"text": "About an hour."}, {"text": "Why do you ask?"}, {"text": "We're closed soon."}])
	await _stand(Vector3(-1.5, 0.05, 4.6), Vector3(-1.5, 1.4, -3.0))
	await _frames(60)
	await _save("3_dialogue_choices")
	game.hud._clear_choices()
	game.hud._on_line("Jamie", "Not anymore.")
	await _frames(60)
	await _save("4_dialogue_line")
	game.hud._speech.text = ""
	game.phone.deliver("cap_1", "Dina", "You still there? Did you check the back latch yet?", "11:27 PM")
	await _frames(40)
	await _save("5_message_toast")
	await _frames(300)
	game.phone.deliver("cap_0", "Dina", "Cash drop goes in the office drawer by 11:55. Don't leave it on the desk.", "11:20 PM")
	game.phone.deliver("cap_2", "Dina", "Police are fifteen minutes out. Don't go looking for him. Get out the front.", "11:40 PM")
	game.phone.deliver("cap_3", "Dina", "I'm on my way.", "11:41 PM", false)
	await _stand(Vector3(-1.5, 0.05, 4.6), Vector3(-1.5, 1.4, -3.0))
	game.phone_ui.toggle()
	await _frames(70)
	await _save("6_phone_open")
	game.phone_ui._scroll_by(-80)
	await _frames(10)
	await _save("6b_phone_scrolled")
	game.phone_ui.toggle()
	await _frames(60)
	await _save("6c_phone_put_away")
	game.tasks.add_task("restock", "Restock 3 products", [
		{"id": "a", "text": "Fill a shelf gap (1/3)"}, {"id": "b", "text": "Fill a shelf gap (2/3)"}, {"id": "c", "text": "Fill a shelf gap (3/3)"}], 50)
	game.tasks.add_task("trash", "Bag the trash", [{"id": "a", "text": "Tie off the trash bag"}, {"id": "b", "text": "Leave it by the rear door"}], 10)
	await _frames(45)
	await _save("7_task_update")
	game.hud._objective_left = 0.0
	game.hud._list_left = 0.0
	await _frames(90)
	await _save("8_quiet_after_fade")
	game.hud.show_checklist()
	await _frames(45)
	await _save("9_checklist_shown")
	game.flow.show_pause()
	await _frames(20)
	await _save("10_pause")
	game.flow.show_settings()
	await _frames(20)
	await _save("11_settings")
	await _stand(get_parent().TITLE_EYE, get_parent().TITLE_AIM)
	game.flow.show_title()
	await _frames(20)
	await _save("12_title")
	game.flow.show_ending("secured")
	await _frames(20)
	await _save("13_ending")
	print("UI CAPTURE COMPLETE dir=", OUT)
	await get_parent().finish_run(0)

func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame

func _stand(pos: Vector3, target: Vector3) -> void:
	player.global_position = pos
	var d := target - (pos + Vector3(0, 1.62, 0))
	player.rotation = Vector3(0, atan2(-d.x, -d.z), 0)
	player.camera.rotation = Vector3(atan2(d.y, Vector2(d.x, d.z).length()), 0, 0)
	await _frames(8)

func _save(shot: String) -> void:
	await _frames(4)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	print("UI CAPTURE ", shot, " ", image.get_size(), " status=", image.save_png("%s/%s.png" % [OUT, shot]))
