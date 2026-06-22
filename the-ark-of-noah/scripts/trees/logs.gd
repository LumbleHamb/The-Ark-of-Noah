extends RigidBody2D

var is_ready := false 
var pull_target: Node2D = null
var logs_pushed_count := 0 

@onready var pull_marker: Marker2D = $pull_marker 
@onready var push_detector: Area2D = $push_detector 

@export var drag_speed := 150.0
@export var rotation_speed := 0.1
@export var base_multiplier := 0.4
@export var stack_penalty := 0.1

func _ready():
	# Configure for manual control
	custom_integrator = true 
	
	if push_detector:
		push_detector.body_entered.connect(_on_push_detector_body_entered)
		push_detector.body_exited.connect(_on_push_detector_body_exited)
	
	await get_tree().create_timer(1.0).timeout
	is_ready = true

# Use _integrate_forces instead of _physics_process when custom_integrator is true
func _integrate_forces(state: PhysicsDirectBodyState2D):
	if is_instance_valid(pull_target):
		var anchor_global = pull_marker.global_position
		var target_pos = pull_target.global_position
		
		# 1. Calculate direction and distance
		var dir = (target_pos - anchor_global).normalized()
		var dist = anchor_global.distance_to(target_pos)
		
		# 2. Set velocity manually
		if dist > 50:
			state.linear_velocity = dir * drag_speed
		else:
			state.linear_velocity = Vector2.ZERO
		
		# 3. Handle rotation
		state.angular_velocity = 0
		rotation = lerp_angle(rotation, anchor_global.angle_to_point(target_pos), rotation_speed)
	else:
		state.linear_velocity = Vector2.ZERO
		state.angular_velocity = 0

func _on_push_detector_body_entered(body: Node2D):
	if body.is_in_group("log") and body != self:
		logs_pushed_count += 1
		update_player_penalty()

func _on_push_detector_body_exited(body: Node2D):
	if body.is_in_group("log") and body != self:
		logs_pushed_count -= 1
		update_player_penalty()

func update_player_penalty():
	if is_instance_valid(pull_target) and pull_target.has_method("set_speed_modifier"):
		var total_mod = clamp(base_multiplier - (logs_pushed_count * stack_penalty), 0.1, 1.0)
		pull_target.set_speed_modifier(total_mod)

func attach_to_target(target: Node2D) -> void:
	if not is_ready or pull_target != null: return
	pull_target = target
	update_player_penalty()

func detach() -> void:
	if is_instance_valid(pull_target) and pull_target.has_method("set_speed_modifier"):
		pull_target.set_speed_modifier(1.0)
	pull_target = null
	logs_pushed_count = 0 

func get_rope_anchor_global() -> Vector2:
	return pull_marker.global_position
