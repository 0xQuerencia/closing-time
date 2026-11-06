class_name HeadLook
extends SkeletonModifier3D
## Turns the neck and head toward a point on top of whatever the animation is doing.
## The rig has painted eyes, so where the head points is where the person is looking.
const MAX_YAW := deg_to_rad(68.0)
const MAX_PITCH_UP := deg_to_rad(22.0)
const MAX_PITCH_DOWN := deg_to_rad(34.0)
const GIVE_UP_YAW := deg_to_rad(115.0)  # further round than this, people turn their body instead
const NECK_SHARE := 0.4
var neck_bone := ""
var head_bone := ""
var target := Vector3.ZERO  # world space
var has_target := false
var turn_speed := 4.0  # rad/s; a person's head settles fast, then holds
var weight := 0.0
var _yaw := 0.0
var _pitch := 0.0
var applied := Quaternion.IDENTITY  # skeleton-space turn added to the head this frame (the skeleton restores poses after skinning)
var facing := Vector3.BACK  # where the face points after the turn, skeleton space

func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	var neck := skeleton.find_bone(neck_bone)
	var head := skeleton.find_bone(head_bone)
	if neck < 0 or head < 0:
		return
	var delta := get_process_delta_time()
	var want_yaw := 0.0
	var want_pitch := 0.0
	var want_weight := 0.0
	if has_target:
		var head_global := skeleton.get_bone_global_pose(head)
		var local_target := skeleton.global_transform.affine_inverse() * target
		var to := local_target - head_global.origin
		var yaw := atan2(to.x, to.z)  # the rigs face skeleton +Z
		if absf(yaw) < GIVE_UP_YAW:
			want_weight = 1.0
			want_yaw = clampf(yaw, -MAX_YAW, MAX_YAW)
			want_pitch = clampf(atan2(to.y, Vector2(to.x, to.z).length()), -MAX_PITCH_DOWN, MAX_PITCH_UP)
	_yaw = move_toward(_yaw, want_yaw, turn_speed * delta)
	_pitch = move_toward(_pitch, want_pitch, turn_speed * 0.7 * delta)
	weight = move_toward(weight, want_weight, 2.5 * delta)
	var head_rot := skeleton.get_bone_global_pose(head).basis.get_rotation_quaternion()
	# Aim from wherever the animation has the face pointing, so idles that already turn the head still land on target.
	var face_in_bone := skeleton.get_bone_global_rest(head).basis.get_rotation_quaternion().inverse() * Vector3.BACK
	var animated := (head_rot * face_in_bone).normalized()
	if weight <= 0.001:
		applied = Quaternion.IDENTITY
		facing = animated
		return
	var aim := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch))
	var full := Quaternion.IDENTITY.slerp(Quaternion(animated, aim), weight)
	var part := Quaternion.IDENTITY.slerp(full, NECK_SHARE)
	var parent := skeleton.get_bone_parent(neck)
	var parent_rot := skeleton.get_bone_global_pose(parent).basis.get_rotation_quaternion() if parent >= 0 else Quaternion.IDENTITY
	var neck_rot := skeleton.get_bone_global_pose(neck).basis.get_rotation_quaternion()
	skeleton.set_bone_pose_rotation(neck, parent_rot.inverse() * part * neck_rot)
	skeleton.set_bone_pose_rotation(head, (part * neck_rot).inverse() * full * head_rot)
	applied = skeleton.get_bone_global_pose(head).basis.get_rotation_quaternion() * head_rot.inverse()
	facing = applied * animated

## Neck and head bone names on either of the game's two rigs, or empty.
static func bones_for(skeleton: Skeleton3D) -> PackedStringArray:
	for pair: PackedStringArray in [PackedStringArray(["neck", "head"]), PackedStringArray(["Neck", "Head"])]:
		if skeleton.find_bone(pair[0]) >= 0 and skeleton.find_bone(pair[1]) >= 0:
			return pair
	return PackedStringArray()
