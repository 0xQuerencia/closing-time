class_name TalkInteractable
extends Interactable
## Lets the player start a conversation with an NPC.
signal talk_requested
var available := false

func _init() -> void:
	super()
	verb = "Talk to"

func can_interact(_actor: Node) -> bool:
	return available

func interact(actor: Node) -> void:
	talk_requested.emit()
	interacted.emit(actor)
