class_name TaskManager
extends Node
## Minimal task log. Objectives only complete through explicit calls from gameplay events.
signal task_added(task_id: String)
signal objective_completed(task_id: String, objective_id: String)
signal task_completed(task_id: String)
signal cleared
var tasks := {}  # id -> {title, objectives: [{id, text, done}], done}

## `priority` controls which open task appears in the player's NEXT guide. Higher values
## are more urgent (a customer or a security problem should outrank routine stock work).
func add_task(id: String, title: String, objectives: Array, priority: int = 0) -> void:
	if tasks.has(id):
		return
	var list := []
	for o in objectives:
		list.append({"id": o.id, "text": o.text, "guide": o.get("guide", ""), "done": false})
	tasks[id] = {"title": title, "objectives": list, "done": false, "priority": priority}
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

## Returns the most useful next step for a player who has lost the thread of the shift.
## The task slip remains the complete record; this is deliberately only one actionable step.
func current_guide() -> Dictionary:
	var selected_task: Dictionary = {}
	var selected_id := ""
	var selected_priority := -2147483648
	for id in tasks:
		var task: Dictionary = tasks[id]
		if task.done:
			continue
		var priority := int(task.get("priority", 0))
		if selected_id == "" or priority > selected_priority:
			selected_id = id
			selected_task = task
			selected_priority = priority
	if selected_id == "":
		return {}
	for objective in selected_task.objectives:
		if objective.done:
			continue
		return {
			"task_id": selected_id,
			"title": selected_task.title,
			"objective": objective.text,
			"hint": objective.get("guide", "")}
	return {}

func clear() -> void:
	tasks.clear()
	cleared.emit()
