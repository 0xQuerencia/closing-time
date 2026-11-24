class_name OriginalOfficeProps
extends RefCounted

const PSX = preload("res://assets/models/psx_pack/asset_loader.gd")

func make(kind: String) -> Node3D:
	return PSX.make(kind)
