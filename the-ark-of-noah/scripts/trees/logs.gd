extends RigidBody2D

var is_pulled := false
var pull_target: Node2D = null

@export var pull_strength: float = 600.0
@export var torque_strength: float = 1800.0

@export var rope_min_length: float = 60.0
@export var rope_max_length: float = 120.0
@export var max_pull_distance: float = 400.0

@onready var rope_anchor: Node2D = $rope_anchor

var spawn_lock := true
var attach_grace_timer := 0.0


func _ready():
	linear_damp = 1.0
	angular_damp = 1.0

	freeze = true
	await get_tree().create_timer(0.15).timeout
	freeze = false

	spawn_lock = false


func _physics_process(delta):
	if spawn_lock:
		return

	if attach_grace_timer > 0.0:
		attach_grace_timer -= delta

	if not is_pulled:
		return

	if pull_target == null or not is_instance_valid(pull_target):
		detach()
		return

	var anchor_world: Vector2 = rope_anchor.global_position
	var target_pos: Vector2 = pull_target.global_position

	var offset: Vector2 = global_position - anchor_world
	var dist: float = offset.length()

	if dist == 0:
		return

	var dir: Vector2 = offset / dist

	# ---------------- SAFETY BREAK ----------------
	if dist > max_pull_distance:
		detach()
		return

	# ---------------- HARD CLAMP (DISABLED DURING GRACE) ----------------
	if attach_grace_timer <= 0.0:
		if dist > rope_max_length:
			linear_velocity += (anchor_world + dir * rope_max_length - global_position) * 0.2

		elif dist < rope_min_length:
			linear_velocity += (anchor_world + dir * rope_min_length - global_position) * 0.2

	# ---------------- FORCE PULL ----------------
	var pull_dir: Vector2 = (target_pos - anchor_world).normalized()
	var force: Vector2 = pull_dir * pull_strength

	apply_central_force(force)

	# ---------------- TORQUE ----------------
	var r: Vector2 = anchor_world - global_position
	var torque: float = r.x * force.y - r.y * force.x

	apply_torque(torque * 0.25 * torque_strength / 1000.0)


func attach_to_target(target: Node2D):
	if target == null:
		return

	pull_target = target
	is_pulled = true

	# IMPORTANT: reset physics state so it doesn't explode
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0

	linear_damp = 5.0
	angular_damp = 8.0

	# give physics time to settle before enforcing constraints
	attach_grace_timer = 0.2

	print("[LOG] attached")


func detach():
	if not is_pulled:
		return

	is_pulled = false
	pull_target = null

	linear_damp = 1.0
	angular_damp = 1.0

	print("[LOG] detached")
