class_name SecurityBeats
extends Node
## M4 story: after the anomaly, the alarm company calls, the cameras show nothing, the power drops, someone comes
## in through the back, and the rear camera is the last thing that sees him. Each beat fires once and waits on
## an event, never on a long timer alone, so a slow player cannot stall it and a fast one cannot skip it.
var director: StoryDirector
var game: Gameplay
var sec: Security
var begun := false
var camera_check_delay := 3.0
var blackout_delay := 5.0
var entry_delay := 3.0
var entry_fallback := 15.0
var walk_fallback := 30.0
var walk_waits_for_player := true

func setup(owner: StoryDirector) -> SecurityBeats:
	director = owner
	game = owner.game
	sec = game.security
	name = "SecurityBeats"
	game.clues.clue_seen.connect(_on_first_clue)
	sec.cctv.feed_viewed.connect(_on_feed_viewed)
	sec.power.breaker_flipped.connect(_on_breaker)
	sec.breaker.cover_opened.connect(_on_cover_opened)
	return self

func _on_first_clue(_id: String) -> void:
	begin()

## Called by the director once the anomaly has happened. Safe to call twice.
func begin() -> void:
	if director.step != StoryDirector.Step.ANOMALY:
		return  # only the anomaly opens the cameras beat
	if not director._once("cameras_begin"):
		return
	begun = true
	director._set_step(StoryDirector.Step.CAMERAS)
	game.tasks.add_task("cameras", "Check the cameras", [
		{"id": "shop", "text": "Shop floor camera", "guide": "Go to the office computer and use E to view the shop floor feed."},
		{"id": "rear", "text": "Rear hall camera", "guide": "Use the office computer's next feed to check the rear hall."}], 130)
	director._record("cameras_begin")
	director._later(camera_check_delay, func(): director._text("dina_5", "Dina", "The alarm company called me. Rear door sensor tripped for a few seconds after midnight. Can you check the cameras on the office computer?", 0, 11))

func _on_feed_viewed(index: int) -> void:
	if not begun:
		return
	game.tasks.complete_objective("cameras", "shop" if index == 0 else "rear")
	if director.step == StoryDirector.Step.CAMERAS and game.tasks.is_complete("cameras"):
		if director._once("blackout_armed"):
			director._later(blackout_delay, blackout)
	elif director.step == StoryDirector.Step.POWER_BACK and index == 1:
		if director._once("walk_armed"):
			director._later(2.0, camera_walk)

# --- the outage ---------------------------------------------------------------------------------

func blackout() -> void:
	if not director._once("blackout"):
		return
	director._set_step(StoryDirector.Step.BLACKOUT)
	director.clock.advance_to(0, 14)
	sec.power.trip_all()
	director._record("blackout")
	game.tasks.add_task("power", "Restore the power", [
		{"id": "cover", "text": "Open the breaker panel", "guide": "The breaker box is in the back hall past the stockroom. Use E on its cover."},
		{"id": "main", "text": "Switch the main on", "guide": "With the cover open, use E on the large main breaker."},
		{"id": "security", "text": "Switch the security breaker on", "guide": "Use E on the smaller security breaker beside the main."}], 140)
	game.interactor.message.emit("Power's out.  T  phone light")
	director._later(3.0, func(): director._text("dina_6", "Dina", "The panel says you're on battery. Breaker box is in the back hall past the stockroom. Try the main.", 0, 15))
	director._later(entry_fallback, leon_enters)

func _on_cover_opened() -> void:
	if director.step == StoryDirector.Step.BLACKOUT:
		game.tasks.complete_objective("power", "cover")
		director._later(entry_delay, leon_enters)

func _on_breaker(id: String, on: bool) -> void:
	if not on or not begun or not director._fired.has("blackout"):
		return
	if id == "main":
		game.tasks.complete_objective("power", "main")
	elif id == "security":
		game.tasks.complete_objective("power", "security")
	if sec.power.all_on() and director.step == StoryDirector.Step.BLACKOUT:
		power_back()

func power_back() -> void:
	if not director._once("power_back"):
		return
	director._set_step(StoryDirector.Step.POWER_BACK)
	director.clock.advance_to(0, 21)
	director._record("power_back")
	game.tasks.add_task("rear_cam", "Look at the rear camera", [{"id": "look", "text": "Check the rear hall camera", "guide": "Return to the office computer and view the rear hall feed."}], 150)
	director._later(3.0, func(): director._text("dina_7", "Dina", "Panel shows the power's back. Can you look at the rear camera for me?", 0, 22))
	director._later(walk_fallback, camera_walk)

# --- Leon ---------------------------------------------------------------------------------------

## Unlocks with the spare key, opens the rear door and stops just inside. Spooked off if the player walks up.
func leon_enters() -> void:
	if not director._once("leon_rear_entry"):
		return
	var leon := sec.spawn_intruder()
	director._record("leon_rear_entry")
	if director.spawn_enabled:
		await leon.enter_building()
		await leon.wait_in_vestibule(60.0)
		if is_instance_valid(leon) and leon.spooked and not director._fired.has("walk"):
			director._record("leon_spooked")
			await leon.leave_building()

func camera_walk() -> void:
	if not director._once("walk"):
		return
	director._record("camera_walk")
	if director.spawn_enabled:
		var leon := sec.intruder
		if is_instance_valid(leon) and leon.leaving:
			await leon.left_building  # already walking out after being spooked: let him finish, then he comes back
		if not is_instance_valid(leon) or not leon.inside or leon.leaving:
			if is_instance_valid(leon):
				leon.queue_free()
			sec.intruder = null
			leon = sec.spawn_intruder()
			await leon.enter_building()
			director._record("walk_leon_inside")
		if walk_waits_for_player:
			var waited := 0.0
			while is_instance_valid(leon) and not sec.cctv.viewing and leon._player_flat_distance() < 4.0 and waited < 40.0:
				await get_tree().create_timer(0.5).timeout
				waited += 0.5
		director._record("walk_started")
		await leon.walk_to_camera(Cctv.CAMS[1].pos - Vector3(0, 1.6, 0))
		director._record("walk_arrived")
	sec.cctv.kill_feed(1)
	director._record("rear_camera_lost")
	director.flags["rear_cam_lost"] = true
	finish()  # he does not leave: the threat beat takes him over, still standing in the hall

func finish() -> void:
	if not director._once("security_done"):
		return
	director._set_step(StoryDirector.Step.SECURITY_DONE)
	director.clock.advance_to(0, 28)
	game.tasks.complete_objective("rear_cam", "look")
	director.flags["m4_complete"] = true
	director._record("security_done")
	director._later(2.0, func(): director._text("dina_8", "Dina", "Police are fifteen minutes out. Don't go looking for him. Get out the front, or lock the office and call them back. I'm on my way.", 0, 29))
	director._later(1.5, director.threat.begin)
