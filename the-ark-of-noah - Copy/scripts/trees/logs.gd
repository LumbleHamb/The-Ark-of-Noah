extends RigidBody2D
class_name Log

## Physics log entity using component architecture.
##
## Components (added as children in scene):
##   - RopeComponent: handles rope pulling behavior
##
## PHYSICS DESIGN — "heavy logs":
##   - Mass = 60 (very heavy; the player barely budges it on contact).
##   - PhysicsMaterial: friction 1.0, bounce 0.0 — grips the ground, never
##     bounces, so stacked logs settle and never "explode" apart.
##   - lock_rotation = true — logs never tumble from collisions (no jitter,
##     no clipping from rotating shapes). The rope still rotates the log via
##     a direct transform write in RopeComponent.apply_forces (which works
##     regardless of lock_rotation, since it sets `entity.rotation`, not
##     angular velocity).
##   - linear_damp / angular_damp = 10 — any velocity acquired from a one-step
##     shove decays within a frame, so logs don't slide around.
##   - can_sleep = false — so the custom integrator keeps running and the rope
##     can always grab a stationary log.
##
## All motion flows through _integrate_forces:
##   - roped  → RopeComponent.apply_forces sets linear_velocity toward player
##              and writes rotation directly (heavy mass is irrelevant — the
##              rope commands velocity, not force).
##   - not roped → snap linear & angular velocity to zero so the log stays put
##              regardless of contact impulses from the player or other logs.
##              Combined with high mass + friction + bounce 0, walking into a
##              log produces only a tiny one-step nudge that immediately cancels.

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
		# Not roped: be heavy and still. Cancel any velocity the physics solver
		# or a contact impulse introduced this step so the log does not slide,
		# jitter, or get pushed around by the player walking into it. High mass
		# (set on the body) already makes the one-step nudge tiny; zeroing here
		# guarantees it snaps back immediately. Stacked logs thus rest stably.
		state.linear_velocity = Vector2.ZERO
		state.angular_velocity = 0.0


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
