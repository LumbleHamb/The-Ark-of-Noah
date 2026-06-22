extends StaticBody2D

@export var min_hits := 4
@export var max_hits := 6

# FIXED: correct path to logs scene
const LOG_SCENE = preload("res://scenes/trees/logs.tscn")

var hp := 0
var is_shaking := false
var is_dead := false

@onready var anim_sprite: AnimatedSprite2D = $trunks_animation

# Leaves (instanced scene)
@onready var leaves_container = get_node_or_null("Leaves")
@onready var leaves_animation = get_node_or_null("Leaves/leaves_animation")
@onready var leaves_particles = get_node_or_null("Leaves/leaves_particles")


func _ready():
	randomize()
	hp = randi_range(min_hits, max_hits)

	print("[TREE] READY")
	print("[TREE] HP =", hp)
	print("[TREE] LOG SCENE =", LOG_SCENE)


func hit():
	if is_dead:
		return

	print("[TREE] HIT RECEIVED")

	hp -= 1
	print("[TREE] HP =", hp)

	play_hit_feedback()
	play_leaf_feedback()

	if hp <= 0:
		print("[TREE] BREAK TRIGGERED")
		break_tree()


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
		var original: Vector2 = leaves_animation.position
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
	print("[TREE] break_tree() → spawning log")

	# stop logic
	set_process(false)
	set_physics_process(false)

	# disable collisions
	collision_layer = 0
	collision_mask = 0

	# hide visuals
	anim_sprite.visible = false
	if leaves_container != null:
		leaves_container.visible = false


	# ---------------- SPAWN LOG ----------------
	if LOG_SCENE == null:
		print("[TREE] ERROR: LOG_SCENE failed to load")
		return

	print("[TREE] SPAWNING LOG")

	var log_instance = LOG_SCENE.instantiate()

	get_tree().current_scene.add_child(log_instance)

	log_instance.global_position = global_position
	log_instance.rotation = rotation


	# ---------------- FALL ANIMATION ----------------
	var start_rot = rotation
	var start_pos = position

	var target_rot = deg_to_rad(randf_range(8, 20))
	var target_pos = position + Vector2(randf_range(-3, 3), 2)

	var t := 0.0
	while t < 1.0:
		t += 0.08
		rotation = lerp(start_rot, target_rot, t)
		position = start_pos.lerp(target_pos, t)
		await get_tree().process_frame

	queue_free()
