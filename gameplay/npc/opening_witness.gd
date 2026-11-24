class_name OpeningWitness
extends Node3D
## Leon waits by the empty lot before the shift's ordinary customer routine begins, then walks away.
const MODEL := "res://assets/models/characters/original/leon_lod1.glb"
const WAIT_POSITION := Vector3(-2.5, 0.0, 12.3)
var _delay: Timer
var _animator: AnimationPlayer
var walking_away := false

func _ready() -> void:
	name = "DistantLotWitness"
	add_to_group("leon_presence")
	add_to_group("opening_witness")
	_delay = Timer.new()
	_delay.one_shot = true
	_delay.timeout.connect(_begin_departure)
	add_child(_delay)
	position = WAIT_POSITION
	var packed := load(MODEL) as PackedScene
	if packed == null:
		queue_free()
		return
	var model := packed.instantiate() as Node3D
	# The authored model faces +Z, toward the store windows from the lot.
	model.rotation.y = 0.0
	add_child(model)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		_animator = players[0] as AnimationPlayer
		for clip in ["Idle", "IdleWait", "IdleShift"]:
			if _animator.has_animation(clip):
				_animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
				_animator.play(clip)
				break
	_delay.start(11.0)

func _begin_departure() -> void:
	if not is_inside_tree():
		return
	if _animator != null:
		for clip in ["Walk", "Stroll"]:
			if _animator.has_animation(clip):
				_animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
				_animator.play(clip, 0.2)
				break
	rotation.y = PI / 2.0
	walking_away = true
	var tween := create_tween()
	tween.tween_property(self, "position", position + Vector3(5.0, 0.0, 1.5), 4.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(queue_free)
