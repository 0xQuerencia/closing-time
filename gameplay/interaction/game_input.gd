class_name GameInput
## Runtime action bindings so gameplay does not depend on editor InputMap state.
const INTERACT := &"interact"
const INSPECT := &"inspect"
const DROP := &"drop_item"
const PHONE := &"phone"
const PHONE_NEXT := &"phone_next"
const PHONE_PREV := &"phone_prev"
const CHOICES: Array[StringName] = [&"choice_1", &"choice_2", &"choice_3"]

static func ensure() -> void:
	_bind(INTERACT, KEY_E)
	_bind(INSPECT, KEY_F)
	_bind(DROP, KEY_Q)
	_bind(PHONE, KEY_TAB)
	_bind(PHONE_NEXT, KEY_RIGHT)
	_bind(PHONE_PREV, KEY_LEFT)
	_bind(CHOICES[0], KEY_1)
	_bind(CHOICES[1], KEY_2)
	_bind(CHOICES[2], KEY_3)

static func _bind(action: StringName, key: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = key
	InputMap.action_add_event(action, event)
