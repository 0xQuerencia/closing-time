extends SceneTree
const Factory = preload("res://scenes/world/original_office_props.gd")

func _initialize() -> void:
	var factory := Factory.new()
	var count := 0
	for id in ["desk","chair","crt","computer","keyboard","phone","mug","crate","extinguisher","camera"]:
		var prop := factory.make(id)
		if prop.get_child_count() == 0:
			printerr("Missing model: " + id)
			prop.free()
			quit(1)
			return
		for child in prop.get_children():
			if not child is MeshInstance3D or child.mesh == null or child.material_override == null:
				printerr("Invalid geometry: " + id)
				prop.free()
				quit(1)
				return
			count += 1
		prop.free()
	print("ORIGINAL PROP TESTS COMPLETE: ", count, " mesh parts")
	quit(0)
