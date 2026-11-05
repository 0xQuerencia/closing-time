class_name CarryPose
extends SkeletonModifier3D
## Bends the right elbow so a customer holds an item up in front of them instead of letting it hang at their side.
## Runs after the animation has been applied, so it works on top of Idle, Walk and the rest.
var upper_bone := ""
var lower_bone := ""
var upper_axis := Vector3.RIGHT
var lower_axis := Vector3.RIGHT
var upper_angle := 0.35
var lower_angle := 1.1
var amount := 0.0  # 0 = arm as animated, 1 = fully carrying

func _process_modification() -> void:
	if amount <= 0.001:
		return
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	_twist(skeleton, upper_bone, upper_axis, upper_angle * amount)
	_twist(skeleton, lower_bone, lower_axis, lower_angle * amount)

func _twist(skeleton: Skeleton3D, bone_name: String, axis: Vector3, angle: float) -> void:
	var bone := skeleton.find_bone(bone_name)
	if bone < 0:
		return
	var pose := skeleton.get_bone_pose_rotation(bone)
	skeleton.set_bone_pose_rotation(bone, pose * Quaternion(axis, angle))
