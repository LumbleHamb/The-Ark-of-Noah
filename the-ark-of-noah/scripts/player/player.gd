extends CharacterBody2D

@onready var anim: AnimatedSprite2D = $player_animation
@onready var hitbox: Area2D = $hitbox

@export var walk_speed := 80.0
@export var run_speed := 140.0

enum State { IDLE, WALK, RUN, ATTACK }

var state: State = State.IDLE
var last_dir := Vector2.DOWN
var input_dir := Vector2.ZERO
var attack_dir := "S"

var hit_targets_this_attack: Array = []

var BASE_OFFSET := Vector2(-32, -43)
var ATTACK_OFFSET := Vector2(-47, -60)


func _ready():
	hitbox.monitoring = false
	hitbox.body_entered.connect(_on_hitbox_body_entered)

	# ensure correct initial offset
	anim.offset = BASE_OFFSET


func _physics_process(_delta):
	read_input()

	position_hitbox(get_dir(last_dir))

	match state:
		State.ATTACK:
			handle_attack_state()
		_:
			handle_movement_state()

	move_and_slide()
	update_animation()
	apply_anim_offset()


# ---------------- INPUT ----------------

func read_input():
	input_dir = Vector2(
		Input.get_action_strength("right") - Input.get_action_strength("left"),
		Input.get_action_strength("down") - Input.get_action_strength("up")
	)

	if input_dir != Vector2.ZERO:
		input_dir = input_dir.normalized()
		last_dir = input_dir

	if state != State.ATTACK and Input.is_action_just_pressed("attack"):
		start_attack()


# ---------------- MOVEMENT ----------------

func handle_movement_state():
	if input_dir == Vector2.ZERO:
		state = State.IDLE
		velocity = Vector2.ZERO
		return

	if Input.is_action_pressed("run"):
		state = State.RUN
		velocity = input_dir * run_speed
	else:
		state = State.WALK
		velocity = input_dir * walk_speed


# ---------------- ATTACK ----------------

func start_attack():
	state = State.ATTACK
	velocity = Vector2.ZERO

	attack_dir = get_dir(last_dir)

	anim.play("attack_" + attack_dir)

	hit_targets_this_attack.clear()
	hitbox.monitoring = true


func handle_attack_state():
	velocity = Vector2.ZERO

	if not anim.is_playing():
		state = State.IDLE
		hitbox.monitoring = false


# ---------------- HITBOX ----------------

func position_hitbox(dir: String):
	var offset := Vector2.ZERO

	match dir:
		"N":
			offset = Vector2(0, -12)
		"S":
			offset = Vector2(0, 12)
		"E":
			offset = Vector2(12, 0)
		"W":
			offset = Vector2(-12, 0)
		"NE":
			offset = Vector2(10, -10)
		"NW":
			offset = Vector2(-10, -10)
		"SE":
			offset = Vector2(10, 10)
		"SW":
			offset = Vector2(-10, 10)

	hitbox.position = offset


func _on_hitbox_body_entered(body):
	if state != State.ATTACK:
		return

	if body in hit_targets_this_attack:
		return

	hit_targets_this_attack.append(body)

	if body.has_method("hit"):
		body.hit()


# ---------------- ANIMATION ----------------

func update_animation():
	var dir = get_dir(last_dir)

	match state:
		State.IDLE:
			play_if_needed("idle_" + dir)

		State.WALK:
			play_if_needed("walk_" + dir)

		State.RUN:
			play_if_needed("run_" + dir)

		State.ATTACK:
			pass


func apply_anim_offset():
	if state == State.ATTACK:
		anim.offset = ATTACK_OFFSET
	else:
		anim.offset = BASE_OFFSET


func play_if_needed(anim_name: String):
	if anim.animation == anim_name:
		return
	anim.play(anim_name)


# ---------------- DIRECTION ----------------

func get_dir(v: Vector2) -> String:
	if v == Vector2.ZERO:
		return "S"

	var angle = rad_to_deg(atan2(v.y, v.x))
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
