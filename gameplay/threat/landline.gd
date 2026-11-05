class_name Landline
extends Interactable
## The office phone. Calling the police is loud: Leon hears it. If the office door is locked he can only stand
## outside it until the responders arrive.
signal call_started
signal call_finished
const PHONE_AT := Vector3(6.9, 0.9, -5.15)
var game
var in_call := false
var called := false

func build(owner_game) -> Landline:
	game = owner_game
	name = "Landline"
	display_name = "office phone"
	verb = "Call the police on the"
	position = PHONE_AT
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.34, 0.24, 0.34)
	shape.shape = box
	add_child(shape)
	game.world.add_child(self)
	game.dialogue.finished.connect(_on_dialogue_finished)
	return self

func _step() -> int:
	return game.director.step if game.director != null else StoryDirector.Step.IDLE

func can_interact(_actor: Node) -> bool:
	return enabled and not in_call and not called and blocked_reason(_actor) == ""

func blocked_reason(_actor: Node) -> String:
	var step := _step()
	if in_call:
		return "Still on the line."
	if called:
		return "They're on their way."
	if step < StoryDirector.Step.CAMERAS:
		return "Nothing to report yet."
	if step < StoryDirector.Step.SECURITY_DONE:
		return "No dial tone. The power's not right."
	if game.dialogue.is_active():
		return ""
	return ""

func prompt_text(actor: Node) -> String:
	return "Call the police" if can_interact(actor) else ""

func inspect(actor: Node) -> String:
	inspected.emit(actor)
	return "An old desk phone with a long curly cord."

func interact(actor: Node) -> void:
	if not can_interact(actor):
		return
	in_call = true
	call_started.emit()
	game.dialogue.start("police_call")
	interacted.emit(actor)

func _on_dialogue_finished(id: String) -> void:
	if id != "police_call" or not in_call:
		return
	in_call = false
	called = true
	call_finished.emit()

func reset() -> void:
	in_call = false
	called = false
