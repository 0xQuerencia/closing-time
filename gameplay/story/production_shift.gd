class_name ProductionShift
extends Node

var director: StoryDirector
var game: Gameplay
var progress := ChapterProgress.new()
var spots: Dictionary = {}
var stage_flags: Dictionary = {}
var ready_for_customers := false
var transitioning := false
var cash_envelope: Product
var journal: EvidenceJournal

func setup(owner: StoryDirector, snapshot: Dictionary, resume := false) -> bool:
	director = owner
	game = owner.game
	if not progress.load_content() or not progress.restore(snapshot):
		return false
	if progress.current_id() not in ["handover", "routine", "closing", "outage", "escape"]:
		return false
	director.event_logged.connect(_on_director_event)
	game.dialogue.finished.connect(_on_dialogue_finished)
	game.phone.read_changed.connect(_on_phone_read)
	_build_spots()
	journal = EvidenceJournal.new()
	add_child(journal)
	journal.setup(self)
	if not resume:
		director._set_step(StoryDirector.Step.INTRO)
		director._add_chores()
		_enter_chapter()
	return true

func _enter_chapter() -> void:
	_refresh_spots()
	match progress.current_id():
		"handover":
			game.clock.elapsed = 5
			game.clock.changed.emit(game.clock.text())
			_task("handover", "Start the shift", [["dina_handover","Read Dina's handover at the counter"],["cooler_counted","Inspect three cooler rows and submit the count"],["mara_served","Serve Mara"]])
			director._text("dina_handover_sms","Dina","I'm in the office. Read the handover sheet first, then count the drinks in the cooler.",23,5)
		"routine":
			director._set_step(StoryDirector.Step.WORK)
			director._text("routine_sms","Kay","You still owe me breakfast. Don't forget to eat something.",23,24)
			_task("routine", "Evening work", [["ben_served","Serve Ben"],["nora_served","Serve Nora"],["delivery_checked","Check the cartons and reconcile the invoice"],["restock_done","Finish stocking shelves"]])
			_sync_chores()
			director._spawn("ben",StoryDirector.Step.BEN)
		"closing":
			director._set_step(StoryDirector.Step.WORK)
			director._text("close_sms","Dina","Cash drop goes in the office drawer. Trash out, then lift the rear latch before you turn the key.",23,49)
			_task("closing_shift", "Closing checklist", [["ruth_served","Serve Ruth"],["leon_first_left","Serve the last customer"],["cash_drop_done","Take the sealed envelope from the counter to the office drawer"],["trash_done","Take the trash to pickup"],["latch_checked","Lock the rear latch"],["leon_second_left","Finish the last transaction"]])
			_sync_chores()
			director._spawn("ruth",StoryDirector.Step.WORK)
		"outage":
			game.phone.deliver("dina_truth","Dina","I saw Evan come back that night. I didn’t see what happened after that. Get out, Jamie.",game.clock.text())
			director._anomaly()
		"escape":
			pass

func _task(id: String, title: String, rows: Array) -> void:
	var objectives: Array[Dictionary] = []
	for row in rows:
		objectives.append({"id":row[0],"text":row[1],"guide":row[1]})
	game.tasks.add_task(id,title,objectives,80)

func _record(id: String) -> bool:
	if not progress.record(id):
		return false
	var task_id: String = {"handover":"handover","routine":"routine","closing":"closing_shift"}.get(progress.current_id(),"")
	if not task_id.is_empty() and id in progress.chapters[progress.index].required:
		game.tasks.complete_objective(task_id,id)
	_refresh_spots()
	_maybe_advance()
	return true

func _maybe_advance() -> void:
	if transitioning:
		return
	var id := progress.current_id()
	if id == "closing" and progress.events.has("leon_first_left") and progress.events.has("cash_drop_done") and progress.events.has("trash_done") and progress.events.has("latch_checked") and not progress.events.has("leon_second_left"):
		if not stage_flags.has("leon_second_scheduled"):
			stage_flags["leon_second_scheduled"] = true
			director._later(8.0,func(): director._spawn("leon2",StoryDirector.Step.LEON_2))
	if id == "escape" or not progress.missing_required().is_empty():
		return
	transitioning = true
	_advance.call_deferred()

func _advance() -> void:
	transitioning = false
	if progress.advance():
		_enter_chapter()

func customer_left(id: String) -> void:
	match id:
		"mara":
			_record("mara_served")
		"ben":
			_record("ben_served")
			director._later(2.0,func(): director._spawn("nora",StoryDirector.Step.WORK))
		"nora":
			_record("nora_served")
		"ruth":
			_record("ruth_served")
			director._later(2.0,func(): director._spawn("leon1",StoryDirector.Step.LEON_1))
		"leon1":
			director._set_step(StoryDirector.Step.LEON_1_AWAY)
			_record("leon_first_left")
		"leon2":
			_record("leon_second_left")

func task_done(_id: String) -> void:
	_sync_chores()

func _sync_chores() -> void:
	if progress.current_id() == "routine" and game.shift.filled >= 3:
		_record("restock_done")
	if progress.current_id() == "closing":
		if game.shift.bag_placed:
			_record("trash_done")
		if game.shift.locked:
			_record("latch_checked")

func _on_dialogue_finished(id: String) -> void:
	if id == "production_handover" and progress.current_id() == "handover":
		_record("dina_handover")
		if not ready_for_customers:
			ready_for_customers = true
			director._spawn("mara",StoryDirector.Step.MARA)
	if id == "inventory_count" and game.dialogue.flags.get("inventory_correct",false):
		_record("cooler_counted")
	if id == "delivery_count" and game.dialogue.flags.get("delivery_correct",false):
		_record("delivery_checked")
	if id == "mara_talk" and game.dialogue.flags.get("mara_memory",false):
		_record("mara_memory")
	if id == "ben_talk" and game.dialogue.flags.get("ben_memory",false):
		_record("ben_memory")

func _on_director_event(id: String) -> void:
	if progress.current_id() != "outage":
		return
	match id:
		"cameras_begin":
			_record("security_alert")
		"power_back":
			_record("power_decision")
		"security_done":
			_record("safety_route_open")
		"clue_boot_prints":
			_record("wet_prints")


func outcome_for(kind: String) -> String:
	var mapped: String = {"escape":"escaped","secured":"rescued","caught":"caught"}.get(kind,kind)
	if mapped != "caught" and progress.has_substantive_evidence():
		mapped = "evidence_preserved"
	if progress.current_id() == "outage" and progress.missing_required().is_empty():
		progress.advance()
	if progress.finish(mapped,true):
		return mapped
	return kind

func _build_spots() -> void:
	# Paperwork is placed on existing shelves/counters, not in the player's collision path.
	_add_spot("dina_handover","handover","Handover sheet",Vector3(-7.8,1.02,4.22),Color("#c7b994"))
	_add_spot("cooler_counted","handover","Cooler inventory card",Vector3(-5.9,1.30,-4.59),Color("#b9bca5"),true)
	_add_spot("delivery_checked","routine","Delivery invoice",Vector3(5.60,.92,1.32),Color("#cfbf9b"))
	_add_spot("cooler_row_a","handover","Cooler row A",Vector3(-7.1,1.3,-4.58),Color("#b9bca5"),true)
	_add_spot("cooler_row_b","handover","Cooler row B",Vector3(-3.96,1.3,-4.58),Color("#b9bca5"),true)
	_add_spot("cooler_row_c","handover","Cooler row C",Vector3(-.82,1.3,-4.58),Color("#b9bca5"),true)
	_add_spot("delivery_a","routine","Carton A label",Vector3(5.42,.75,1.05),Color("#bfa67d"))
	_add_spot("delivery_b","routine","Carton B label",Vector3(6.45,.75,1.42),Color("#bfa67d"))
	_add_spot("cash_pickup","closing","Prepare cash envelope",Vector3(-7.65,1.01,4.42),Color("#bfa67d"))
	_add_spot("cash_drop_done","closing","Office cash drawer",Vector3(8.10,.80,-4.91),Color("#bfa67d"))
	var positions := {
		"opening_photo":[Vector3(-8.3,1.74,5.87),true],
		"employee_schedule":[Vector3(5.14,1.59,-2.85),true],
		"evan_photo":[Vector3(6.82,.81,-5.00),false],
		"bypass_clipping":[Vector3(-7.9,1.01,.2),false],
		"delivery_note":[Vector3(5.91,.91,1.32),false],
		"locker_note":[Vector3(5.05,1.3,-1.3),true],
		"owner_circular":[Vector3(5.17,1.60,-3.65),true],
		"termination_notice":[Vector3(8.18,.80,-5.02),false],
		"missing_notice":[Vector3(-8.65,1.75,5.86),true],
		"evan_notebook":[Vector3(6.78,.81,-4.92),false],
		"ledger_copy":[Vector3(7.15,.81,-5.13),false],
		"training_binder":[Vector3(7.03,.83,-4.82),false],
		"key_log":[Vector3(5.35,1.2,-3.11),true],
		"dvr_clip":[Vector3(7.72,.81,-4.76),false],
		"arthur_message":[Vector3(8.43,.80,-4.92),false],
		"maintenance_log":[Vector3(4.58,1.35,-4.82),true]
	}
	for id in positions:
		var clue: Dictionary = progress.evidence[id]
		_add_spot(id,clue.chapter,clue.title,positions[id][0],Color("#c5b999"),positions[id][1])
	_refresh_spots()

func _add_spot(id: String, chapter: String, title: String, pos: Vector3, color: Color, vertical := false) -> void:
	var spot := Interactable.new()
	spot.display_name = title
	spot.verb = "Read" if progress.evidence.has(id) else "Check"
	spot.description = str(progress.evidence[id].text) if progress.evidence.has(id) else title
	var size := Vector3(.20,.28,.045) if vertical else Vector3(.22,.035,.18)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size + Vector3(.035,.04,.035)
	shape.shape = box
	spot.add_child(shape)
	var mesh := MeshInstance3D.new()
	var paper := BoxMesh.new()
	paper.size = size
	mesh.mesh = paper
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = .96
	mesh.material_override = material
	spot.add_child(mesh)
	var text_label := Label3D.new()
	text_label.text = title.to_upper()
	text_label.font_size = 24
	text_label.pixel_size = .0007
	text_label.modulate = Color("#312b21")
	text_label.outline_size = 0
	text_label.position = Vector3(0,.0,.025) if vertical else Vector3(0,.019,0)
	if not vertical:
		text_label.rotation.x = -PI/2
	spot.add_child(text_label)
	spot.position = pos
	spot.interacted.connect(func(_actor): _use(id))
	spot.inspected.connect(func(_actor): _use(id))
	game.world.add_child(spot)
	spots[id] = {"node":spot,"chapter":chapter}

func _refresh_spots() -> void:
	for id in spots:
		var row: Dictionary = spots[id]
		var node: Interactable = row.node
		var available: bool = row.chapter == progress.current_id()
		if id == "cash_pickup" and (is_instance_valid(cash_envelope) or progress.events.has("cash_drop_done")):
			available = false
		node.visible = available
		node.enabled = available

func _use(id: String) -> void:
	if not spots.has(id) or spots[id].chapter != progress.current_id():
		return
	if progress.evidence.has(id):
		var clue: Dictionary = progress.evidence[id]
		game.interactor.message.emit(clue.text)
		_record(id)
		return
	match id:
		"dina_handover":
			if not progress.events.has(id) and not game.dialogue.is_active():
				game.dialogue.start("production_handover")
		"cooler_row_a", "cooler_row_b", "cooler_row_c":
			var count: int = {"cooler_row_a":4,"cooler_row_b":3,"cooler_row_c":4}[id]
			stage_flags[id] = true
			game.interactor.message.emit("Row %s: %d bottles." % [id.right(1).to_upper(),count])
		"cooler_counted":
			if progress.events.has(id):
				return
			if not _checked(["cooler_row_a","cooler_row_b","cooler_row_c"]):
				game.interactor.message.emit("Check rows A, B and C before signing.")
			elif not game.dialogue.is_active():
				game.dialogue.flags.erase("inventory_correct")
				game.dialogue.start("inventory_count")
		"delivery_a", "delivery_b":
			stage_flags[id] = true
			game.interactor.message.emit("Carton %s: %s." % [id.right(1).to_upper(),"received, seal intact" if id == "delivery_a" else "received; third carton not delivered"])
		"delivery_checked":
			if progress.events.has(id):
				return
			if not _checked(["delivery_a","delivery_b"]):
				game.interactor.message.emit("Inspect both carton labels before signing the invoice.")
			elif not game.dialogue.is_active():
				game.dialogue.flags.erase("delivery_correct")
				game.dialogue.start("delivery_count")
		"cash_pickup":
			if game.interactor.held != null:
				game.interactor.message.emit("Put down what you're holding first.")
				return
			if not is_instance_valid(cash_envelope) and not progress.events.has("cash_drop_done"):
				cash_envelope = game.spawn_product("cash_envelope",null)
				game.interactor.pick_up(cash_envelope)
				_refresh_spots()
				game.interactor.message.emit("Sealed. Take this to the office drawer.")
		"cash_drop_done":
			if progress.events.has(id):
				return
			if not is_instance_valid(cash_envelope) or game.interactor.held != cash_envelope:
				game.interactor.message.emit("Bring the sealed cash envelope from the counter.")
				return
			game.interactor.release_held()
			cash_envelope.queue_free()
			_record(id)
			game.interactor.message.emit("Cash secured in the drawer.")

func _checked(ids: Array) -> bool:
	for id in ids:
		if not stage_flags.has(id):
			return false
	return true

func snapshot() -> Dictionary:
	return progress.snapshot()

func _on_phone_read() -> void:
	if progress.current_id() != "outage":
		return
	for entry in game.phone.threads.get("Dina",[]):
		if entry.id == "dina_truth" and entry.read:
			_record("dina_statement")
			return
