class_name OpeningCheckpoint
extends RefCounted

const PATH := "user://closing_time_opening.json"
const TEMP := "user://closing_time_opening.tmp"

static func read() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not data is Dictionary:
		return {}
	var progress := ChapterProgress.new()
	if not progress.load_content() or not progress.restore(data):
		return {}
	if progress.current_id() not in ["apartment","route9","handover"] or not progress.outcome.is_empty():
		return {}
	return data

static func write(data: Dictionary) -> bool:
	var file := FileAccess.open(TEMP,FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	file.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(TEMP),ProjectSettings.globalize_path(PATH)) == OK

static func erase() -> void:
	for path in [PATH,TEMP]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

static func resume(tree: SceneTree,data: Dictionary) -> void:
	tree.paused = false
	tree.set_meta("closing_time_opening_preview",data)
	var scene: String = {"apartment":"res://scenes/apartment/apartment.tscn","route9":"res://scenes/route9/route9.tscn","handover":"res://scenes/world/market_root.tscn"}.get(data.get("chapter"),"res://scenes/apartment/apartment.tscn")
	tree.change_scene_to_file(scene)
