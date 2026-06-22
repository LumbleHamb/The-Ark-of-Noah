extends CharacterBody2D

@onready var anim: AnimatedSprite2D = $player_animation
@onready var hitbox: Area2D = $hitbox
@onready var rope_range: Area2D = $rope_range
@onready var rope_line: Line2D = $rope_line 

@export var walk_speed: float = 80.0
@export var run_speed: float = 140.0
@export var rope_hard_limit: float = 140.0

var current_speed_mod: float = 1.0

# Animation Offsets
var BASE_OFFSET: Vector2 = Vector2(-32, -43)
var ATTACK_OFFSET: Vector2 = Vector2(-47, -60)

enum State { IDLE, WALK, RUN, ATTACK }

var state: State = State.IDLE
var last_dir: Vector2 = Vector2.DOWN
var input_dir: Vector2 = Vector2.ZERO
var attached_log: Node2D = null

func _ready() -> void:
	hitbox.monitoring = false
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	anim.offset = BASE_OFFSET
	if rope_line: rope_line.visible = false

func _physics_process(_delta: float) -> void:
	read_input()
	match state:
		State.ATTACK: handle_attack_state()
		_: handle_movement_state()
	
	move_and_slide()
	update_animation()
	apply_anim_offset()
	update_rope_visuals()

# ---------------- SPEED MODIFIER SYSTEM ----------------
func set_speed_modifier(mod: float) -> void:
	current_speed_mod = mod

# ---------------- ROPE SYSTEM ----------------
func update_rope_visuals() -> void:
	if not is_instance_valid(attached_log) or not rope_line:
		if attached_log: detach_rope()
		return
	
	rope_line.visible = true
	var log_anchor = attached_log.get_rope_anchor_global()
	rope_line.points = [Vector2.ZERO, to_local(log_anchor)]
	
	if global_position.distance_to(attached_log.global_position) > rope_hard_limit:
		detach_rope()

func try_attach_rope() -> void:
	for body in rope_range.get_overlapping_bodies():
		if body.is_in_group("log"):
			attach_rope(body)
			return

func attach_rope(log_body: Node2D) -> void:
	attached_log = log_body
	if log_body.has_method("attach_to_target"): 
		log_body.attach_to_target(self)

func detach_rope() -> void:
	if attached_log and attached_log.has_method("detach"): 
		attached_log.detach()
	attached_log = null
	if rope_line: rope_line.visible = false

# ---------------- INPUT & MOVEMENT ----------------
func read_input() -> void:
	input_dir = Vector2(
		Input.get_action_strength("right") - Input.get_action_strength("left"), 
		Input.get_action_strength("down") - Input.get_action_strength("up")
	)
	
	if input_dir.length() > 1.0:
		input_dir = input_dir.normalized()
		
	if input_dir != Vector2.ZERO: 
		last_dir = input_dir.normalized()
	
	if state != State.ATTACK and Input.is_action_just_pressed("attack"): 
		start_attack()
	if Input.is_action_just_pressed("attach_rope"):
		if attached_log != null: detach_rope()
		else: try_attach_rope()

func handle_movement_state() -> void:
	if input_dir == Vector2.ZERO:
		state = State.IDLE
		velocity = Vector2.ZERO
		return
	state = State.RUN if Input.is_action_pressed("run") else State.WALK
	velocity = input_dir * (run_speed if state == State.RUN else walk_speed) * current_speed_mod

# ---------------- ATTACK & ANIMATION ----------------
func start_attack() -> void:
	state = State.ATTACK
	velocity = Vector2.ZERO
	anim.play("attack_" + get_dir(last_dir))
	hitbox.monitoring = true

func handle_attack_state() -> void:
	if not anim.is_playing():
		state = State.IDLE
		hitbox.monitoring = false

func _on_hitbox_body_entered(body: Node) -> void:
	if state == State.ATTACK and body.has_method("hit"): 
		body.hit()

func apply_anim_offset() -> void:
	anim.offset = BASE_OFFSET if state != State.ATTACK else ATTACK_OFFSET

func update_animation() -> void:
	var dir = get_dir(last_dir)
	if state == State.IDLE: anim.play("idle_" + dir)
	elif state == State.WALK: anim.play("walk_" + dir)
	elif state == State.RUN: anim.play("run_" + dir)

func get_dir(v: Vector2) -> String:
	if v == Vector2.ZERO: return "S"
	var angle: float = rad_to_deg(atan2(v.y, v.x))
	if angle < 0: angle += 360
	if angle < 22.5 or angle >= 337.5: return "E"
	elif angle < 67.5: return "SE"
	elif angle < 112.5: return "S"
	elif angle < 157.5: return "SW"
	elif angle < 202.5: return "W"
	elif angle < 247.5: return "NW"
	elif angle < 292.5: return "N"
	else: return "NE"
