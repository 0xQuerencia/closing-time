class_name Interactable
extends StaticBody3D
## Contract for anything the player can aim at: activate (E) and inspect (F).
const LAYER := 2
signal interacted(actor: Node)
signal inspected(actor: Node)
@export var display_name := "Object"
@export var verb := "Use"
@export_multiline var description := ""
var enabled := true

func _init() -> void:
	collision_layer = LAYER
	collision_mask = 0

func can_interact(_actor: Node) -> bool:
	return enabled

## Why the action is unavailable; shown dimmed instead of a prompt.
func blocked_reason(_actor: Node) -> String:
	return ""

func prompt_text(actor: Node) -> String:
	return "%s %s" % [verb, display_name] if can_interact(actor) else ""

func interact(actor: Node) -> void:
	interacted.emit(actor)

func inspect(actor: Node) -> String:
	inspected.emit(actor)
	return description
