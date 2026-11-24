extends SceneTree

const Progress = preload("res://gameplay/story/chapter_progress.gd")
var failures := 0

func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + label)

func _initialize() -> void:
	var p = Progress.new()
	check(p.load_content(), "load authored content")
	if p.chapters.is_empty():
		quit(1)
		return
	check(p.evidence.size() == 24, "24 authored discoveries")
	check(not p.advance(), "cannot skip apartment")
	check(not p.record("dvr_clip"), "future clue rejected")
	check(not p.finish("escaped", true), "cannot end before finale")
	for i in range(6):
		for event in p.chapters[i].required:
			check(p.record(event), "record " + event)
			check(not p.record(event), "duplicate rejected " + event)
		check(p.advance(), "advance chapter " + str(i))
	check(not p.finish("escaped", false), "unverified ending rejected")
	check(not p.finish("evidence_preserved", true), "evidence ending requires evidence")
	var saved: Dictionary = p.snapshot()
	var restored = Progress.new()
	check(restored.load_content(), "load second instance")
	check(restored.restore(saved), "restore chapter")
	check(restored.current_id() == "escape", "restore finale")
	check(restored.finish("rescued", true), "rescue without optional evidence")
	check(not restored.finish("caught", true), "ending immutable")
	var forged := saved.duplicate(true)
	forged.events.erase("keys_taken")
	check(not restored.restore(forged), "reject skipped required event")
	var collector = Progress.new()
	check(collector.load_content(), "load evidence route")
	for i in range(6):
		for event in collector.chapters[i].required + collector.chapters[i].optional:
			check(collector.record(event), "collector " + event)
		check(collector.advance(), "collector advance")
	check(collector.finish("evidence_preserved", true), "evidence ending")
	print("CHAPTER PROGRESSION TESTS COMPLETE: ", failures, " failures")
	quit(0 if failures == 0 else 1)
