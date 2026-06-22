extends CharacterBody2D

@onready var anim: AnimatedSprite2D = $player_animation
@onready var hitbox: Area2D = $hitbox
@onready var rope_range: Area2D = $rope_range
@onready var rope_line: Line2D = $rope_line

@export var walk_speed: float = 80.0
@export var run_speed: float = 140.0

@export var rope_soft_limit: float = 90.0
@export var rope_hard_limit: float = 140.0

enum State { IDLE, WALK, RUN, ATTACK }

var state: State = State.IDLE
var last_dir: Vector2 = Vector2.DOWN
var input_dir: Vector2 = Vector2.ZERO
var attack_dir: String = "S"

var hit_targets_this_attack: Array[Node] = []

var BASE_OFFSET: Vector2 = Vector2(-32, -43)
var ATTACK_OFFSET: Vector2 = Vector2(-47, -60)

var attached_log: Node2D = null


func _ready() -> void:
	hitbox.monitoring = false
	hitbox.body_entered.connect(_on_hitbox_body_entered)

	anim.offset = BASE_OFFSET
	rope_line.visible = false


func _physics_process(_delta: float) -> void:
	read_input()

	position_hitbox(get_dir(last_dir))

	match state:
		State.ATTACK:
			handle_attack_state()
		_:
			handle_movement_state()

	update_rope_tension()

	move_and_slide()

	update_animation()
	apply_anim_offset()
	update_rope()


# ---------------- INPUT ----------------

func read_input() -> void:
	input_dir = Vector2(
		Input.get_action_strength("right") - Input.get_action_strength("left"),
		Input.get_action_strength("down") - Input.get_action_strength("up")
	)

	if input_dir != Vector2.ZERO:
		input_dir = input_dir.normalized()
		last_dir = input_dir

	if state != State.ATTACK and Input.is_action_just_pressed("attack"):
		start_attack()

	# TOGGLE ROPE
	if Input.is_action_just_pressed("attach_rope"):
		if attached_log != null:
			detach_rope()
		else:
			try_attach_rope()


# ---------------- MOVEMENT ----------------

func handle_movement_state() -> void:
	if input_dir == Vector2.ZERO:
		state = State.IDLE
		velocity = Vector2.ZERO
		return

	var base_speed: float = walk_speed

	if Input.is_action_pressed("run"):
		state = State.RUN
		base_speed = run_speed
	else:
		state = State.WALK

	velocity = input_dir * base_speed


# ---------------- ATTACK ----------------

func start_attack() -> void:
	state = State.ATTACK
	velocity = Vector2.ZERO

	attack_dir = get_dir(last_dir)

	anim.play("attack_" + attack_dir)

	hit_targets_this_attack.clear()
	hitbox.monitoring = true


func handle_attack_state() -> void:
	velocity = Vector2.ZERO

	if not anim.is_playing():
		state = State.IDLE
		hitbox.monitoring = false


# ---------------- HITBOX ----------------

func position_hitbox(dir: String) -> void:
	var offset: Vector2 = Vector2.ZERO

	match dir:
		"N": offset = Vector2(0, -12)
		"S": offset = Vector2(0, 12)
		"E": offset = Vector2(12, 0)
		"W": offset = Vector2(-12, 0)
		"NE": offset = Vector2(10, -10)
		"NW": offset = Vector2(-10, -10)
		"SE": offset = Vector2(10, 10)
		"SW": offset = Vector2(-10, 10)

	hitbox.position = offset


func _on_hitbox_body_entered(body: Node) -> void:
	if state != State.ATTACK:
		return

	if body in hit_targets_this_attack:
		return

	hit_targets_this_attack.append(body)

	if body.has_method("hit"):
		body.hit()


# ---------------- ROPE SYSTEM ----------------

func try_attach_rope() -> void:
	if attached_log != null:
		return

	for body in rope_range.get_overlapping_bodies():
		if body.is_in_group("log"):
			attach_rope(body)
			return


func attach_rope(log_body: Node2D) -> void:
	if log_body == null:
		return

	attached_log = log_body

	if log_body.has_method("attach_to_target"):
		log_body.attach_to_target(self)

	rope_line.visible = true


func detach_rope() -> void:
	if attached_log == null:
		return

	if attached_log.has_method("detach"):
		attached_log.detach()

	attached_log = null
	rope_line.visible = false


# ---------------- ROPE VISUAL ----------------

func update_rope() -> void:
	if attached_log == null:
		rope_line.visible = false
		return

	if not is_instance_valid(attached_log):
		attached_log = null
		rope_line.visible = false
		return

	var anchor: Node2D = attached_log.get_node_or_null("rope_anchor")
	if anchor == null:
		return

	rope_line.visible = true
	rope_line.clear_points()

	rope_line.add_point(Vector2.ZERO)
	rope_line.add_point(to_local(anchor.global_position))

	var dist: float = global_position.distance_to(anchor.global_position)

	if dist > rope_hard_limit:
		detach_rope()


# ---------------- ROPE TENSION ----------------

func update_rope_tension() -> void:
	if attached_log == null:
		return

	var anchor: Node2D = attached_log.get_node_or_null("rope_anchor")
	if anchor == null:
		return

	var dist: float = global_position.distance_to(anchor.global_position)

	if dist > rope_soft_limit:
		var t: float = clamp(
			(dist - rope_soft_limit) / (rope_hard_limit - rope_soft_limit),
			0.0,
			1.0
		)

		var slow_factor: float = lerp(1.0, 0.1, t)
		velocity *= slow_factor


# ---------------- ANIMATION ----------------

func update_animation() -> void:
	var dir: String = get_dir(last_dir)

	match state:
		State.IDLE:
			play_if_needed("idle_" + dir)
		State.WALK:
			play_if_needed("walk_" + dir)
		State.RUN:
			play_if_needed("run_" + dir)
		State.ATTACK:
			pass


func apply_anim_offset() -> void:
	anim.offset = BASE_OFFSET if state != State.ATTACK else ATTACK_OFFSET


func play_if_needed(anim_name: String) -> void:
	if anim.animation != anim_name:
		anim.play(anim_name)


# ---------------- DIRECTION ----------------

func get_dir(v: Vector2) -> String:
	if v == Vector2.ZERO:
		return "S"

	var angle: float = rad_to_deg(atan2(v.y, v.x))
	if angle < 0:
		angle += 360

	if angle < 22.5 or angle >= 337.5:
		return "E"
	elif angle < 67.5:
		return "SE"
	elif angle < 112.5:
		return "S"
	elif angle < 157.5:
		return "SW"
	elif angle < 202.5:
		return "W"
	elif angle < 247.5:
		return "NW"
	elif angle < 292.5:
		return "N"
	else:
		return "NE"
