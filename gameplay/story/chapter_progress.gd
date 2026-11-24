class_name ChapterProgress
extends RefCounted

signal chapter_changed(id: String)
signal event_recorded(id: String)

const DATA_PATH := "res://gameplay/story/data/production_story.json"
const OUTCOMES := ["escaped", "rescued", "evidence_preserved", "caught"]

var chapters: Array = []
var evidence: Dictionary = {}
var index := 0
var events: Dictionary = {}
var discoveries: Dictionary = {}
var outcome := ""

func load_content(path: String = DATA_PATH) -> bool:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or parsed.get("schema") != 1:
		return false
	var rows = parsed.get("chapters")
	var clues = parsed.get("evidence")
	if not rows is Array or rows.size() != 7 or not clues is Array:
		return false
	var ids: Dictionary = {}
	var all_events: Dictionary = {}
	for row in rows:
		if not row is Dictionary or not row.get("id") is String or ids.has(row.id):
			return false
		if not row.get("required") is Array or not row.get("optional") is Array:
			return false
		ids[row.id] = true
		for event in row.required + row.optional:
			if not event is String or all_events.has(event):
				return false
			all_events[event] = row.id
	var next_evidence: Dictionary = {}
	for clue in clues:
		if not clue is Dictionary or not clue.get("id") is String or next_evidence.has(clue.id):
			return false
		if not ids.has(clue.get("chapter")) or not clue.get("text") is String:
			return false
		if all_events.get(clue.id) != clue.chapter:
			return false
		next_evidence[clue.id] = clue
	chapters = rows
	evidence = next_evidence
	index = 0
	events.clear()
	discoveries.clear()
	outcome = ""
	return true

func current_id() -> String:
	return "" if chapters.is_empty() else str(chapters[index].id)

func record(id: String) -> bool:
	if chapters.is_empty() or not outcome.is_empty() or events.has(id):
		return false
	var row: Dictionary = chapters[index]
	if id not in row.required and id not in row.optional:
		return false
	events[id] = true
	if evidence.has(id):
		discoveries[id] = true
	event_recorded.emit(id)
	return true

func missing_required() -> Array[String]:
	var missing: Array[String] = []
	if chapters.is_empty():
		return missing
	for id in chapters[index].required:
		if not events.has(id):
			missing.append(id)
	return missing

func advance() -> bool:
	if chapters.is_empty() or index >= chapters.size() - 1 or not missing_required().is_empty() or not outcome.is_empty():
		return false
	index += 1
	chapter_changed.emit(current_id())
	return true

func finish(result: String, verified: bool) -> bool:
	if current_id() != "escape" or not verified or not outcome.is_empty() or result not in OUTCOMES:
		return false
	if result == "evidence_preserved" and not has_substantive_evidence():
		return false
	outcome = result
	return true

func has_substantive_evidence() -> bool:
	return discoveries.has("training_binder") and (discoveries.has("dvr_clip") or discoveries.has("dina_statement"))

func snapshot() -> Dictionary:
	return {"schema": 1, "chapter": current_id(), "events": events.keys(), "outcome": outcome}

func restore(data: Dictionary) -> bool:
	if chapters.is_empty() or data.get("schema") != 1 or not data.get("events") is Array:
		return false
	var next_index := -1
	for i in chapters.size():
		if chapters[i].id == data.get("chapter"):
			next_index = i
	if next_index < 0:
		return false
	var permitted: Dictionary = {}
	for i in range(next_index + 1):
		for id in chapters[i].required + chapters[i].optional:
			permitted[id] = true
	var next_events: Dictionary = {}
	var next_discoveries: Dictionary = {}
	for id in data.events:
		if not id is String or not permitted.has(id) or next_events.has(id):
			return false
		next_events[id] = true
		if evidence.has(id):
			next_discoveries[id] = true
	for i in range(next_index):
		for id in chapters[i].required:
			if not next_events.has(id):
				return false
	var next_outcome = data.get("outcome", "")
	if not next_outcome is String or (next_outcome != "" and (next_index != chapters.size() - 1 or next_outcome not in OUTCOMES)):
		return false
	if next_outcome == "evidence_preserved" and not (next_discoveries.has("training_binder") and (next_discoveries.has("dvr_clip") or next_discoveries.has("dina_statement"))):
		return false
	index = next_index
	events = next_events
	discoveries = next_discoveries
	outcome = next_outcome
	chapter_changed.emit(current_id())
	return true
