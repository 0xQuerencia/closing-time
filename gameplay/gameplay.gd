class_name Gameplay
extends Node
## Composition root for M2 systems. Consumes the world's named markers; owns no world geometry.
signal customer_finished(customer: Customer)
const CUSTOMER_GAP := 7.0
var world: Node3D
var player: CharacterBody3D
var interactor: Interactor
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
var markers := {}
var profiles: Array[Dictionary] = []
var next_profile := 0
var customers_served := 0
var auto_customers := true

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
	interactor.placement_validator = func(pos, _item): return checkout.placement_reason(pos)
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
	shift = ShiftTasks.new().build(self)
	clues = Clues.new().build(world)
	security = Security.new()
	add_child(security)
	security.build(self)
	director = StoryDirector.new()
	add_child(director)
	director.setup(self)
	_stock_shelves()
	if auto_customers:
		director.start()

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
		{"id": "at_counter", "text": "Customer at the counter"},
		{"id": "scanned", "text": "Scan their items"},
		{"id": "paid", "text": "Take payment at the register"}])
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
