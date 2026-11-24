class_name Gameplay
extends Node
## Composition root for M2 systems. Consumes the world's named markers; owns no world geometry.
signal customer_finished(customer: Customer)
const CUSTOMER_GAP := 7.0
var world: Node3D
var player: CharacterBody3D
var interactor: Interactor
var soundscape: Soundscape
var checkout: Checkout
var dialogue: DialogueRunner
var tasks: TaskManager
var hud: GameHud
var phone: PhoneModel
var clock: StoryClock
var shift: ShiftTasks
var clues: Clues
var director: StoryDirector
var security: Security
var phone_ui: PhoneUI
var flow: FlowUI
var markers := {}
var profiles: Array[Dictionary] = []
var next_profile := 0
var customers_served := 0
var auto_customers := true
var production_spawn: Transform3D
var production_look: Vector3

func setup(world_root: Node3D, player_body: CharacterBody3D, auto := true) -> void:
	world = world_root
	player = player_body
	auto_customers = auto
	name = "Gameplay"
	GameInput.ensure()
	for key in ["NPCEntrance", "FrontDoor", "NPCExit", "CheckoutPoint", "NPCQueue"]:
		markers[key] = world.get_tree().get_first_node_in_group(key).global_position
	profiles = CustomerProfiles.build(markers)
	dialogue = DialogueRunner.new()
	add_child(dialogue)
	dialogue.load_file("res://gameplay/dialogue/data/story.json")
	tasks = TaskManager.new()
	add_child(tasks)
	checkout = Checkout.new()
	checkout.build(world)
	checkout.sale_opened.connect(_on_sale_opened)
	checkout.item_scanned.connect(_on_item_scanned)
	checkout.sale_completed.connect(_on_sale_completed)
	interactor = Interactor.new()
	add_child(interactor)
	interactor.setup(player.camera, player)
	interactor.placement_validator = func(pos, item):
		if item.product_id == "cash_envelope" and checkout.in_zone(pos):
			return "That is the deposit, not a sale item."
		return checkout.placement_reason(pos)
	hud = GameHud.new()
	add_child(hud)
	hud.setup(interactor, dialogue, tasks)
	phone = PhoneModel.new()
	clock = StoryClock.new()
	clock.changed.connect(hud.set_clock)
	hud.set_clock(clock.text())
	phone_ui = PhoneUI.new()
	add_child(phone_ui)
	phone_ui.setup(phone, clock)
	phone_ui.attach_camera(player.camera)
	shift = ShiftTasks.new().build(self)
	clues = Clues.new().build(world)
	security = Security.new()
	add_child(security)
	security.build(self)
	soundscape = Soundscape.new().setup(self)
	add_child(soundscape)
	director = StoryDirector.new()
	add_child(director)
	director.setup(self)
	_stock_shelves()
	SetDressing.new().build(self)
	flow = FlowUI.new().setup(self)
	add_child(flow)
	director.threat.ending.connect(func(kind): flow.show_ending(director.production.outcome_for(kind) if director.production != null else kind))
	flow.retry_requested.connect(retry)
	flow.start_requested.connect(begin_shift)
	flow.continue_requested.connect(continue_game)
	flow.restart_requested.connect(restart_game)
	flow.quit_requested.connect(func(): get_tree().quit())
	production_spawn = player.global_transform
	production_look = player.camera.rotation
	if get_tree().has_meta("closing_time_opening_preview"):
		var incoming: Dictionary = get_tree().get_meta("closing_time_opening_preview")
		get_tree().remove_meta("closing_time_opening_preview")
		begin_production.call_deferred(incoming)
	elif auto_customers:
		begin_shift()

func begin_production(snapshot: Dictionary) -> void:
	player.global_transform = production_spawn
	player.camera.rotation = production_look
	player.enabled = true
	flow.hide_all()
	profiles = CustomerProfiles.production(markers)
	dialogue.load_file("res://gameplay/dialogue/data/production_dialogue.json")
	if not director.start_production(snapshot):
		flow.show_title()
		return
	save_checkpoint("shift_start")

func begin_shift() -> void:
	if director.start():
		save_checkpoint("shift_start")

func _unhandled_input(event: InputEvent) -> void:
	for i in GameInput.CHOICES.size():
		if event.is_action_pressed(GameInput.CHOICES[i]):
			dialogue.choose(i)
	if event.is_action_pressed(GameInput.INTERACT) and interactor.focus == null:
		dialogue.skip()

func spawn_product(id: String, at) -> Product:
	var product := Product.new().setup(id, world)
	product.placed.connect(checkout.on_product_placed)
	if at is Vector3:
		world.add_child(product)
		product.global_position = at
	return product

func _stock_shelves() -> void:
	# Spare stock on the counter's staff end and on the coffee cabinet.
	var spots := {
		"cola": Vector3(-7.55, 0.955, 4.4), "noodles": Vector3(-7.2, 0.955, 4.4),
		"water": Vector3(-8.35, 0.92, -0.2), "coffee": Vector3(-8.35, 0.92, -0.65)}
	for id in spots:
		spawn_product(id, spots[id])

func spawn_customer_by_id(profile_id: String) -> Customer:
	for index in profiles.size():
		if profiles[index].id == profile_id:
			next_profile = maxi(next_profile, index + 1)
			return _spawn_profile(profiles[index])
	push_error("Unknown customer profile: " + profile_id)
	return null

func spawn_customer() -> Customer:
	if next_profile >= profiles.size():
		return null
	var profile := profiles[next_profile]
	next_profile += 1
	return _spawn_profile(profile)

func _spawn_profile(profile: Dictionary) -> Customer:
	var customer := Customer.new().setup(self, profile)
	world.add_child(customer)
	customer.global_position = profile.start
	tasks.add_task("serve_" + profile.id, "Serve the customer", [
		{"id": "at_counter", "text": "Customer at the counter", "guide": "Meet them at the front counter and wait for the sale to open."},
		{"id": "scanned", "text": "Scan their items", "guide": "Aim at each item on the counter and press E to scan it."},
		{"id": "paid", "text": "Take payment at the register", "guide": "Aim at the card terminal and press E to take payment."}], 100)
	customer.finished.connect(_on_customer_finished)
	customer.run()
	return customer

func _task_id() -> String:
	if checkout.customer == null or not "profile" in checkout.customer:
		return ""
	return "serve_" + checkout.customer.profile.id

func _on_sale_opened(_customer: Node) -> void:
	tasks.complete_objective(_task_id(), "at_counter")

func _on_item_scanned(_product: Product) -> void:
	if checkout.scanned_count() == checkout.items.size():
		tasks.complete_objective(_task_id(), "scanned")

func _on_sale_completed(_tx: Dictionary) -> void:
	tasks.complete_objective(_task_id(), "scanned")
	tasks.complete_objective(_task_id(), "paid")
	customers_served += 1

func _on_customer_finished(customer: Customer) -> void:
	customer_finished.emit(customer)

# --- checkpoints --------------------------------------------------------------------------------

var checkpoint_data := {}
var persist_saves := false  # only the shipped game writes to disk; tests keep checkpoints in memory

func save_checkpoint(checkpoint: String) -> void:
	checkpoint_data = SaveGame.snapshot(self, checkpoint)
	if persist_saves:
		if SaveGame.write(checkpoint_data):
			OpeningCheckpoint.erase()

## Rebuild the shop at the last checkpoint and start the next beat. Used for retry and for Continue.
func load_checkpoint(data := {}) -> bool:
	var source := data if not data.is_empty() else checkpoint_data
	if source.is_empty():
		return false
	if source.get("production", {}) is Dictionary and not source.get("production", {}).is_empty():
		if source.checkpoint == "shift_start":
			restart_game()
			return true
		dialogue.load_file("res://gameplay/dialogue/data/production_dialogue.json")
		if not director.restore_production(source.production):
			return false
	if not SaveGame.apply(self, source):
		return false
	checkpoint_data = source
	if source.checkpoint == "closing_time":
		director.threat.begin()
	return true

func retry() -> void:
	if not load_checkpoint() and director.step != StoryDirector.Step.IDLE:
		restart_game()

func continue_game() -> void:
	var data := SaveGame.read()
	if data.get("checkpoint") == "shift_start" and not data.get("production", {}).is_empty():
		begin_production(data.production)
	elif data.is_empty() or data.checkpoint == "shift_start" or not load_checkpoint(data):
		begin_shift()

func restart_game() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
