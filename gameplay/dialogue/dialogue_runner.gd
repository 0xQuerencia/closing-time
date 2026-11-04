class_name DialogueRunner
extends Node
## Short data-driven conversations. Lines auto-advance; choices wait for the player but never freeze the world.
signal line_shown(speaker: String, text: String)
signal choices_shown(options: Array)
signal finished(conversation_id: String)
const BASE_HOLD := 1.5
const PER_CHAR := 0.045
var flags := {}
var active_id := ""
var current_choices: Array = []
var time_scale_for_tests := 1.0
var _conversations := {}
var _nodes := {}
var _timer: Timer

func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_advance)
	add_child(_timer)

func load_file(path: String) -> int:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed == null or not parsed is Dictionary:
		push_error("DIALOGUE LOAD FAIL: " + path)
		return 0
	_conversations.merge(parsed, true)
	return parsed.size()

func has_conversation(id: String) -> bool:
	return _conversations.has(id)

func is_active() -> bool:
	return active_id != ""

## Starts a conversation; any conversation already running is cancelled first.
func start(id: String) -> bool:
	if not _conversations.has(id):
		push_error("DIALOGUE MISSING: " + id)
		return false
	cancel()
	active_id = id
	_nodes = _conversations[id].nodes
	_show(_conversations[id].start)
	return true

func cancel() -> void:
	if active_id == "":
		return
	var id := active_id
	active_id = ""
	current_choices = []
	_timer.stop()
	finished.emit(id)

var _next_id := ""

func _show(node_id: String) -> void:
	if node_id == "" or not _nodes.has(node_id):
		cancel()
		return
	var node: Dictionary = _nodes[node_id]
	_apply(node.get("set", {}))
	if node.has("text"):
		line_shown.emit(node.get("speaker", ""), node.text)
	if node.has("choices"):
		current_choices = node.choices
		_timer.stop()
		choices_shown.emit(current_choices)
		return
	current_choices = []
	_next_id = node.get("next", "")
	if time_scale_for_tests <= 0.0:
		_advance()
	else:
		_timer.start((BASE_HOLD + PER_CHAR * String(node.get("text", "")).length()) * time_scale_for_tests)

func _advance() -> void:
	if active_id == "":
		return
	_show(_next_id)

## Player skips the current line.
func skip() -> void:
	if active_id != "" and current_choices.is_empty():
		_timer.stop()
		_advance()

func choose(index: int) -> bool:
	if active_id == "" or index < 0 or index >= current_choices.size():
		return false
	var option: Dictionary = current_choices[index]
	current_choices = []
	_apply(option.get("set", {}))
	line_shown.emit("Jamie", option.text)
	_next_id = option.get("next", "")
	if time_scale_for_tests > 0.0:
		_timer.start(BASE_HOLD * 0.6 * time_scale_for_tests)
	else:
		_advance()
	return true

func _apply(changes: Dictionary) -> void:
	for key in changes:
		flags[key] = changes[key]
