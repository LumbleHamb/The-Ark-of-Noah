extends StaticBody2D

@export var min_hits := 4
@export var max_hits := 6

const LOG_SCENE = preload("res://scenes/trees/logs.tscn")

var hp := 0
var is_shaking := false
var is_dead := false

@onready var anim_sprite: AnimatedSprite2D = $trunks_animation
@onready var leaves_container = get_node_or_null("Leaves")
@onready var leaves_animation = get_node_or_null("Leaves/leaves_animation")
@onready var leaves_particles = get_node_or_null("Leaves/leaves_particles")


func _ready():
	randomize()
	hp = randi_range(min_hits, max_hits)

	print("[TREE] READY")
	print("[TREE] HP =", hp)


func hit():
	if is_dead:
		return

	hp -= 1

	play_hit_feedback()
	play_leaf_feedback()

	if hp <= 0:
		# IMPORTANT: avoid physics flush crash
		call_deferred("break_tree")


# ---------------- FEEDBACK ----------------

func play_hit_feedback():
	flash()
	jiggle()


func flash():
	if anim_sprite == null:
		return

	anim_sprite.modulate = Color(1.3, 1.3, 1.3)
	await get_tree().create_timer(0.06).timeout
	anim_sprite.modulate = Color(1, 1, 1)


func jiggle():
	if is_shaking:
		return

	is_shaking = true

	var original_pos = position
	position += Vector2(randf_range(-2, 2), randf_range(-1, 1))

	await get_tree().create_timer(0.05).timeout
	position = original_pos

	is_shaking = false


# ---------------- LEAF FEEDBACK ----------------

func play_leaf_feedback():
	if leaves_container == null:
		return

	if leaves_animation != null:
		var original = leaves_animation.position
		leaves_animation.position += Vector2(randf_range(-1, 1), randf_range(-0.5, 0.5))

		await get_tree().create_timer(0.05).timeout
		leaves_animation.position = original

	if leaves_particles != null:
		leaves_particles.restart()


# ---------------- DEATH → LOG SPAWN ----------------

func break_tree():
	if is_dead:
		return

	is_dead = true
	print("[TREE] BREAK")

	# safe physics shutdown (deferred-safe)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	set_physics_process(false)
	set_process(false)

	# hide visuals
	anim_sprite.visible = false
	if leaves_container != null:
		leaves_container.visible = false

	# ---------------- SPAWN LOG ----------------
	if LOG_SCENE == null:
		print("[TREE] ERROR: LOG_SCENE missing")
		return

	var log_instance = LOG_SCENE.instantiate()

	# IMPORTANT: spawn into active world scene
	get_tree().current_scene.add_child(log_instance)

	# slight offset prevents ground clipping + weird initial physics impulse
	log_instance.global_position = global_position + Vector2(0, -6)
	log_instance.rotation = rotation

	# stabilize spawn state
	if log_instance is RigidBody2D:
		log_instance.linear_velocity = Vector2.ZERO
		log_instance.angular_velocity = 0.0

	# mark rope-compatible
	log_instance.add_to_group("log")

	# ---------------- FALL ANIMATION ----------------
	var start_rot = rotation
	var start_pos = position

	var target_rot = deg_to_rad(randf_range(10, 25))
	var target_pos = position + Vector2(randf_range(-3, 3), 2)

	var t := 0.0
	while t < 1.0:
		t += 0.08
		rotation = lerp(start_rot, target_rot, t)
		position = start_pos.lerp(target_pos, t)
		await get_tree().process_frame

	queue_free()
