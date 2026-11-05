class_name PhoneModel
extends RefCounted
## Message threads. Every message has an id and is delivered at most once.
signal message_received(thread: String, entry: Dictionary)
signal read_changed
var threads := {"Dina": [], "Kay": []}
var _delivered := {}

## Returns false (and does nothing) if this id was already delivered.
func deliver(id: String, thread: String, text: String, time_text: String, from_me := false) -> bool:
	if _delivered.has(id) or not threads.has(thread):
		return false
	_delivered[id] = true
	var entry := {"id": id, "text": text, "time": time_text, "me": from_me, "read": from_me}
	threads[thread].append(entry)
	message_received.emit(thread, entry)
	return true

func has_delivered(id: String) -> bool:
	return _delivered.has(id)

func unread_count(thread := "") -> int:
	var count := 0
	for name in threads:
		if thread != "" and name != thread:
			continue
		for entry in threads[name]:
			if not entry.read:
				count += 1
	return count

func mark_read(thread: String) -> void:
	var changed := false
	for entry in threads.get(thread, []):
		if not entry.read:
			entry.read = true
			changed = true
	if changed:
		read_changed.emit()

func message_count() -> int:
	var total := 0
	for name in threads:
		total += threads[name].size()
	return total

func export_state() -> Dictionary:
	var out := {}
	for name in threads:
		out[name] = (threads[name] as Array).duplicate(true)
	return {"threads": out, "delivered": _delivered.keys()}

func import_state(state: Dictionary) -> void:
	for name in threads:
		threads[name] = []
		for entry in state.threads.get(name, []):
			threads[name].append((entry as Dictionary).duplicate(true))
	_delivered = {}
	for id in state.delivered:
		_delivered[id] = true
	read_changed.emit()
