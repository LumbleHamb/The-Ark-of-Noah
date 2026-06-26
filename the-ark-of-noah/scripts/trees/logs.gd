extends RigidBody2D
class_name Log

## Physics log entity using component architecture.
##
## Components (added as children in scene):
##   - RopeComponent: handles rope pulling behavior

var rope: RopeComponent = null


func _ready() -> void:
	# Find the RopeComponent
	rope = get_node_or_null("RopeComponent") as RopeComponent
	
	# Configure for manual control
	custom_integrator = true


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if rope and rope.is_attached():
		rope.apply_forces(state)
	else:
		state.linear_velocity = Vector2.ZERO
		state.angular_velocity = 0


func attach_to_target(target: Node2D) -> bool:
	if rope:
		return rope.attach_to_target(target)
	return false


func detach() -> void:
	if rope:
		rope.detach()


func get_rope_anchor_global() -> Vector2:
	if rope:
		return rope.get_rope_anchor_global()
	return global_position
