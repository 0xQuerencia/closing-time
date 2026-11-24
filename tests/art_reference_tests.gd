extends SceneTree

const ArtReference = preload("res://scenes/world/art_reference.gd")
const Factory = preload("res://scenes/world/original_office_props.gd")
var failures := 0

func _initialize() -> void:
	if not ArtReference.active():
		printerr("Missing --art-reference argument")
		quit(1)
		return
	var exterior := ArtReference.scene("res://assets/models/exterior.glb")
	if exterior == null:
		failures += 1
	else:
		exterior.free()
	var factory := Factory.new()
	for id in ArtReference.PROPS:
		var model := ArtReference.prop(id,factory)
		if model == null:
			failures += 1
			continue
		if id == "crt":
			if not ArtReference.set_screen(model, StandardMaterial3D.new()):
				failures += 1
			if model.find_child("OriginalCRTGlass",true,false) != null:
				printerr("Reference CRT fell back to the procedural mesh")
				failures += 1
		var meshes := model.find_children("*","MeshInstance3D",true,false)
		if meshes.is_empty():
			failures += 1
		model.free()
	for id in ["ben","gus","jamie","leon"]:
		var character := ArtReference.customer(id)
		if character == null:
			failures += 1
			continue
		if character.find_children("*","Skeleton3D",true,false).is_empty():
			failures += 1
		character.free()
	print("ART REFERENCE TESTS COMPLETE failures=",failures)
	quit(1 if failures else 0)
