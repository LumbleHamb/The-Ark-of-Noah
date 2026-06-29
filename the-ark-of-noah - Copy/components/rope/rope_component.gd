class_name RopeComponent
extends Component

## Rope pulling for logs and draggable objects.
## Moves a RigidBody2D toward the attached target with stacking speed penalty.

signal attached(target: Node2D)
signal detached()

@export var drag_speed: float = 150.0
@export var rotation_speed: float = 0.1
@export var base_multiplier: float = 0.4
@export var stack_penalty: float = 0.1

var is_ready: bool = false
var pull_target: Node2D = null
var logs_pushed_count: int = 0
var pull_marker: Marker2D = null

func _component_ready() -> void:
	var entity := get_entity()
	pull_marker = entity.get_node_or_null("pull_marker") as Marker2D
	if not pull_marker:
		pull_marker = Marker2D.new()
		pull_marker.name = "pull_marker"
		pull_marker.position = Vector2(16, 0)
		entity.add_child(pull_marker)
	var push_detector: Area2D = entity.get_node_or_null("push_detector") as Area2D
	if push_detector:
		push_detector.body_entered.connect(_on_push_detector_body_entered)
		push_detector.body_exited.connect(_on_push_detector_body_exited)
	await get_tree().create_timer(1.0).timeout
	is_ready = true

## Attaches rope to a target. Returns false if not ready or already attached.
func attach_to_target(target: Node2D) -> bool:
	if not is_ready or pull_target != null:
		return false
	pull_target = target
	_update_player_penalty()
	attached.emit(target)
	return true

## Detaches and resets the player's speed modifier.
func detach() -> void:
	if is_instance_valid(pull_target) and pull_target.has_method("set_speed_modifier"):
		pull_target.set_speed_modifier(1.0)
	pull_target = null
	logs_pushed_count = 0
	detached.emit()

func is_attached() -> bool:
	return pull_target != null

## Returns the global position of the rope anchor point.
func get_rope_anchor_global() -> Vector2:
	if pull_marker:
		return pull_marker.global_position
	return Vector2.ZERO

## Applies physics forces to drag the entity toward the attached target.
func apply_forces(state: PhysicsDirectBodyState2D) -> void:
	if not is_instance_valid(pull_target):
		state.linear_velocity = Vector2.ZERO
		state.angular_velocity = 0
		return
	var anchor_global := pull_marker.global_position if pull_marker else (get_entity() as Node2D).global_position
	var target_pos := pull_target.global_position
	var dir := (target_pos - anchor_global).normalized()
	var dist := anchor_global.distance_to(target_pos)
	if dist > 50:
		state.linear_velocity = dir * drag_speed
	else:
		state.linear_velocity = Vector2.ZERO
	state.angular_velocity = 0
	var entity := get_entity() as Node2D
	if entity:
		entity.rotation = lerp_angle(entity.rotation, anchor_global.angle_to_point(target_pos), rotation_speed)

func _on_push_detector_body_entered(body: Node2D) -> void:
	if body.is_in_group("log") and body != get_entity():
		logs_pushed_count += 1
		_update_player_penalty()

func _on_push_detector_body_exited(body: Node2D) -> void:
	if body.is_in_group("log") and body != get_entity():
		logs_pushed_count -= 1
		_update_player_penalty()

func _update_player_penalty() -> void:
	if is_instance_valid(pull_target) and pull_target.has_method("set_speed_modifier"):
		var total_mod: float = clampf(base_multiplier - (logs_pushed_count * stack_penalty), 0.1, 1.0)
		pull_target.set_speed_modifier(total_mod)
