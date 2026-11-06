class_name StoryDirector
extends Node
## M3 story: ordered beats with once-only triggers. All progress is driven by events (sales, customers
## leaving, chores, clues), never by one long timer, so a slow or dawdling player cannot stall it.
signal step_changed(step: Step)
signal event_logged(entry: String)
enum Step { IDLE, INTRO, MARA, BEN, WORK, LEON_1, LEON_1_AWAY, LEON_2, ANOMALY, CAMERAS, BLACKOUT, POWER_BACK, SECURITY_DONE, THREAT, ENDED }
const LEON_RETURN_AFTER_CHORES := 2
const LEON_RETURN_MIN_AWAY := 6.0
const LEON_RETURN_MAX_AWAY := 60.0
var game: Gameplay
var phone: PhoneModel
var clock: StoryClock
var step := Step.IDLE
var flags := {}
var log: Array[String] = []
var spawn_log: Array[String] = []
var spawn_enabled := true
var delay_scale := 1.0
var _fired := {}
var _away := 0.0
var _chores_done := {}
var beats: SecurityBeats
var threat: ThreatBeats

func setup(owner_game: Gameplay) -> StoryDirector:
	game = owner_game
	phone = game.phone
	clock = game.clock
	name = "StoryDirector"
	game.customer_finished.connect(_on_customer_finished)
	game.checkout.sale_completed.connect(_on_sale_completed)
	game.tasks.task_completed.connect(_on_task_completed)
	game.shift.latch_locked.connect(func(): flags["rear_latch_checked"] = true; _record("rear_latch_checked"))
	game.clues.clue_seen.connect(_on_clue_seen)
	beats = SecurityBeats.new().setup(self)
	add_child(beats)
	threat = ThreatBeats.new().setup(self)
	add_child(threat)
	return self

func start() -> bool:
	if step != Step.IDLE:
		return false
	_set_step(Step.INTRO)
	_add_chores()
	if spawn_enabled and get_tree().get_nodes_in_group("opening_witness").is_empty():
		game.world.add_child(OpeningWitness.new())
	_later(3.0, func(): _text("dina_1", "Dina", "Please count the back cooler. And double-check the loading door.", 23, 26))
	_later(6.0, func(): _spawn("mara", Step.MARA))
	return true

func _process(delta: float) -> void:
	if step != Step.LEON_1_AWAY:
		return
	_away += delta
	var enough := _chores_done.size() >= LEON_RETURN_AFTER_CHORES and _away >= LEON_RETURN_MIN_AWAY
	if enough or _away >= LEON_RETURN_MAX_AWAY:
		_spawn("leon2", Step.LEON_2)

# --- beats ------------------------------------------------------------------------------------

func _on_sale_completed(_tx: Dictionary) -> void:
	var who := _customer_id()
	match who:
		"mara":
			flags["sale_1_completed"] = true
			clock.advance_to(23, 31)
		"ben":
			flags["sale_2_completed"] = true
			clock.advance_to(23, 41)
		"leon1":
			flags["leon_visit_1"] = true
			clock.advance_to(23, 53)
		"leon2":
			flags["leon_visit_2"] = true
			clock.advance_to(0, 4)
	if who != "":
		_record("sale_" + who)

func _on_customer_finished(customer: Customer) -> void:
	var id: String = customer.profile.id
	match id:
		"mara":
			if step != Step.MARA:
				return
			_set_step(Step.BEN)
			_later(3.0, func(): _text("dina_2", "Dina", "Remember the freezer count. And the back latch sticks. Lift it before you turn the key.", 23, 33))
			_later(5.0, func(): _spawn("ben", Step.BEN))
		"ben":
			if step != Step.BEN:
				return
			_set_step(Step.WORK)
			_later(2.0, func(): _text("kay_1", "Kay", "Still doing inventory? Respectfully, why?", 23, 44))
			_later(8.0, func(): _text("dina_3", "Dina", "Cash drop goes in the office drawer by 11:55. Don't leave it on the desk.", 23, 49))
			_later(14.0, func(): _spawn("leon1", Step.LEON_1))
		"leon1":
			if step != Step.LEON_1:
				return
			_away = 0.0
			_set_step(Step.LEON_1_AWAY)
		"leon2":
			if step != Step.LEON_2:
				return
			_anomaly()

func _anomaly() -> void:
	if not _once("anomaly"):
		return
	_set_step(Step.ANOMALY)
	clock.advance_to(0, 6)
	game.clues.activate()
	if game.security != null:
		game.security.pulse_rear_door()
	game.tasks.add_task("look_back", "Something's off in back", [
		{"id": "spare_key", "text": "Check the key hooks", "guide": "Go to the office and inspect the hooks beside the desk."},
		{"id": "cash_envelope", "text": "Check the cash drop", "guide": "In the office, inspect the cash envelope on the desk."},
		{"id": "boot_prints", "text": "Follow the wet prints", "guide": "Leave the office and follow the wet prints toward the rear hall."}], 120)
	_later(3.0, func(): _text("kay_2", "Kay", "A man bought the same water twice and acted like I'd never seen him.", 0, 7, true))
	_later(8.0, func(): _text("kay_3", "Kay", "Maybe he really likes hydration.", 0, 8))
	_later(13.0, func(): _text("dina_4", "Dina", "If the alarm trips, call the police, not me.", 0, 9))
	if beats != null:
		get_tree().create_timer(40.0).timeout.connect(beats.begin)  # real time: a player who ignores the clues still gets the cameras

# --- chores and clues -------------------------------------------------------------------------

func _add_chores() -> void:
	var tasks := game.tasks
	tasks.add_task("restock", "Stock three products", [
		{"id": "s1", "text": "Fill a shelf gap (1/3)", "guide": "In the back stockroom, take one item from the open carton. Bring it to any glowing orange gap on the middle aisle shelves and press E."},
		{"id": "s2", "text": "Fill a shelf gap (2/3)", "guide": "Return to the open carton in the back stockroom for another item, then press E at an orange gap on the middle aisle shelves."},
		{"id": "s3", "text": "Fill a shelf gap (3/3)", "guide": "Take the last item from the open stockroom carton and press E at the final orange gap on the middle aisle shelves."}], 10)
	tasks.add_task("trash", "Bag the trash", [
		{"id": "bag", "text": "Tie off the trash bag", "guide": "At the left end of the checkout counter, press E on the full trash bin to tie the bag."},
		{"id": "rear", "text": "Leave it by the rear door", "guide": "Carry the tied bag through the staff hall to the rear loading door. Look for the TRASH PICKUP mark on the floor and press E there."}], 20)
	tasks.add_task("latch", "Check the rear-door latch", [
		{"id": "lift", "text": "Lift the latch", "guide": "At the rear loading door, find the wide metal lever marked LIFT THEN TURN and press E."},
		{"id": "lock", "text": "Turn the key", "guide": "Press E on the round metal key cylinder directly below the raised lever."}], 25)
	game.shift.restocked.connect(func(n): tasks.complete_objective("restock", "s%d" % n))
	game.shift.trash_bagged.connect(func(): tasks.complete_objective("trash", "bag"))
	game.shift.trash_placed.connect(func(): tasks.complete_objective("trash", "rear"))
	game.shift.latch_lifted.connect(func(): tasks.complete_objective("latch", "lift"))
	game.shift.latch_locked.connect(func(): tasks.complete_objective("latch", "lock"))

func _on_task_completed(task_id: String) -> void:
	if task_id in ["restock", "trash", "latch"]:
		_chores_done[task_id] = true
		_record("chore_" + task_id)

func _on_clue_seen(clue_id: String) -> void:
	flags[clue_id + "_seen"] = true
	game.tasks.complete_objective("look_back", clue_id)
	_record("clue_" + clue_id)

# --- plumbing ---------------------------------------------------------------------------------

func _customer_id() -> String:
	var who: Node = game.checkout.customer
	return who.profile.id if who != null and "profile" in who else ""

func _spawn(profile_id: String, next_step: Step) -> void:
	if not _once("spawn_" + profile_id):
		return
	_set_step(next_step)
	if profile_id == "leon1":
		clock.advance_to(23, 52)
	elif profile_id == "leon2":
		clock.advance_to(0, 1)
	spawn_log.append(profile_id)
	_record("spawn_" + profile_id)
	if spawn_enabled:
		game.spawn_customer_by_id(profile_id)

func _text(id: String, thread: String, body: String, hour: int, minute: int, from_me := false) -> void:
	clock.advance_to(hour, minute)
	if phone.deliver(id, thread, body, clock.text(), from_me):
		_record("msg_" + id)

func _set_step(next: Step) -> void:
	step = next
	step_changed.emit(next)

func _once(key: String) -> bool:
	if _fired.has(key):
		return false
	_fired[key] = true
	return true

func _record(entry: String) -> void:
	log.append(entry)
	event_logged.emit(entry)

func _later(seconds: float, action: Callable) -> void:
	if delay_scale <= 0.0:
		action.call_deferred()
	else:
		get_tree().create_timer(seconds * delay_scale).timeout.connect(action)
