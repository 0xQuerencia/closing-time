class_name TaskManager
extends Node
## Minimal task log. Objectives only complete through explicit calls from gameplay events.
signal task_added(task_id: String)
signal objective_completed(task_id: String, objective_id: String)
signal task_completed(task_id: String)
signal cleared
var tasks := {}  # id -> {title, objectives: [{id, text, done}], done}

func add_task(id: String, title: String, objectives: Array) -> void:
	if tasks.has(id):
		return
	var list := []
	for o in objectives:
		list.append({"id": o.id, "text": o.text, "done": false})
	tasks[id] = {"title": title, "objectives": list, "done": false}
	task_added.emit(id)

func complete_objective(task_id: String, objective_id: String) -> bool:
	if not tasks.has(task_id) or tasks[task_id].done:
		return false
	for o in tasks[task_id].objectives:
		if o.id == objective_id and not o.done:
			o.done = true
			objective_completed.emit(task_id, objective_id)
			_check_done(task_id)
			return true
	return false

func _check_done(task_id: String) -> void:
	var task: Dictionary = tasks[task_id]
	for o in task.objectives:
		if not o.done:
			return
	task.done = true
	task_completed.emit(task_id)

func is_complete(task_id: String) -> bool:
	return tasks.has(task_id) and tasks[task_id].done

func completed_count() -> int:
	return tasks.values().filter(func(t): return t.done).size()

func active_ids() -> Array:
	return tasks.keys().filter(func(k): return not tasks[k].done)

func clear() -> void:
	tasks.clear()
	cleared.emit()
