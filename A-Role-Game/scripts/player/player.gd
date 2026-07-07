class_name Player
extends CharacterBody2D


## Player controller.
##
## Handles:
## - Movement
## - Combat
## - Player states
## - Health reactions
##
## Components:
## - MovementComponent
## - PlayerAnimationComponent
## - AttackComponent
## - HealthComponent
## - StaminaComponent
## - BlockComponent


# ==================================================
# COMPONENT REFERENCES
# ==================================================

@onready var movement: MovementComponent = $MovementComponent

@onready var animator: PlayerAnimationComponent = $PlayerAnimationComponent

@onready var attack: AttackComponent = $AttackComponent

@onready var health: HealthComponent = $HealthComponent

@onready var stamina: StaminaComponent = $StaminaComponent

var block_comp: Node


# ==================================================
# STATE
# ==================================================

enum State
{
	IDLE,
	WALK,
	RUN,
	ATTACK,
	HURT,
	DEAD,
	DASH,
	BLOCK,
	SQUAT,
	JUMP
}


var state: State = State.IDLE

var last_direction: Vector2 = Vector2.DOWN

var input_enabled: bool = true



# ==================================================
# READY
# ==================================================

func _ready() -> void:

	# Set FLOATING motion mode for top-down physics (better push behavior)
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING


	block_comp = get_node("BlockComponent")


	if attack:

		attack.attack_started.connect(
			_on_attack_started
		)

		attack.attack_finished.connect(
			_on_attack_finished
		)



	if health:

		health.damaged.connect(
			_on_damaged
		)

		health.died.connect(
			_on_died
		)



	if block_comp:

		block_comp.block_started.connect(
			_on_block_started
		)

		block_comp.block_ended.connect(
			_on_block_ended
		)



# ==================================================
# MAIN LOOP
# ==================================================

func _physics_process(_delta: float) -> void:


	if state == State.DEAD:

		velocity = Vector2.ZERO

		move_and_slide()

		return



	if not input_enabled:

		velocity = Vector2.ZERO

		move_and_slide()

		return



	_process_input()



	# Attack and hurt override movement input, but preserve velocity
	# so the player slides through hits instead of dead-stopping.
	var overrides_movement: bool = (
		state == State.ATTACK
		or state == State.HURT
		or state == State.DASH
		or state == State.BLOCK
		or state == State.SQUAT
		or state == State.JUMP
	)

	if not overrides_movement:

		_process_movement()



	move_and_slide()

	# Push enemies when colliding with them (prevents getting stuck)
	_push_colliding_enemies()


	_update_animation()





# ==================================================
# MOVEMENT
# ==================================================

func _process_movement() -> void:


	if not movement:

		return



	movement.read_input()



	if movement.input_dir != Vector2.ZERO:

		last_direction = movement.input_dir.normalized()



	velocity = movement.calculate_velocity()



	match movement.move_state:


		MovementComponent.MoveState.IDLE:

			state = State.IDLE


		MovementComponent.MoveState.WALK:

			state = State.WALK


		MovementComponent.MoveState.RUN:

			state = State.RUN





# ==================================================
# INPUT
# ==================================================

func _process_input() -> void:


	if Input.is_action_just_pressed("attack"):

		_start_attack()


	if Input.is_action_just_pressed("dash"):

		_start_dash()


	if Input.is_action_just_pressed("block"):

		_start_block()


	if Input.is_action_just_pressed("squat"):

		_start_squat()


	if Input.is_action_just_pressed("jump"):

		_start_jump()





# ==================================================
# ATTACK
# ==================================================

func _start_attack() -> void:


	if not attack:

		return



	if not attack.can_attack():

		return



	state = State.ATTACK

	velocity = Vector2.ZERO



	var direction: String = "S"



	if animator:

		direction = animator.get_dir_from_vector(
			last_direction
		)

		animator.play_attack(
			direction
		)



	attack.start_attack(
		direction
	)



func _start_dash() -> void:


	if not movement:

		return


	if state == State.DASH or state == State.ATTACK or state == State.HURT or state == State.DEAD:

		return


	state = State.DASH

	movement.start_dash(last_direction)

	velocity = movement.calculate_velocity()


	await get_tree().create_timer(movement.dash_duration).timeout


	if state == State.DASH:

		state = State.IDLE

		movement.end_special()



func _start_block() -> void:


	if not block_comp:

		return


	if state == State.ATTACK or state == State.HURT or state == State.DEAD:

		return


	block_comp.toggle_block()



func _start_squat() -> void:


	if state == State.ATTACK or state == State.HURT or state == State.DEAD:

		return


	if state == State.SQUAT:

		state = State.IDLE

		movement.end_special()

		return


	state = State.SQUAT

	movement.start_squat()

	velocity = Vector2.ZERO



func _start_jump() -> void:


	if state == State.ATTACK or state == State.HURT or state == State.DEAD:

		return


	if state == State.JUMP:

		return


	state = State.JUMP

	movement.start_jump(last_direction)

	velocity = movement.calculate_velocity()


	await get_tree().create_timer(movement.jump_duration).timeout


	if state == State.JUMP:

		state = State.IDLE

		movement.end_special()





func _on_attack_started(direction: String) -> void:


	if animator:

		animator.play_attack(
			direction
		)





func _on_attack_finished() -> void:


	if state == State.ATTACK:

		state = State.IDLE





# ==================================================
# DAMAGE
# ==================================================

func _on_damaged(
	_amount: int,
	_remaining: int
) -> void:


	if state == State.DEAD:

		return

	state = State.HURT



	if animator and animator.has_method("play_hurt"):

		animator.play_hurt(
			animator.get_dir_from_vector(
				last_direction
			)
		)



	await get_tree().create_timer(
		0.25
	).timeout



	if state != State.DEAD:

		state = State.IDLE





func _on_died() -> void:


	state = State.DEAD

	velocity = Vector2.ZERO



	if animator and animator.has_method("play_death"):

		animator.play_death(
			animator.get_dir_from_vector(
				last_direction
			)
		)





# ==================================================
# ENEMY PUSH
# ==================================================

func _push_colliding_enemies() -> void:

	# When the player collides with enemies, push them away
	# to prevent the 'getting stuck' problem.
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		if not collision:
			continue
		var collider := collision.get_collider()
		if collider is CharacterBody2D and collider != self:
			# Check if this has a HealthComponent (it is an enemy)
			if collider.get_node_or_null("HealthComponent") != null:
				# Push the enemy away from the player
				var push_dir: Vector2 = (collider.global_position - global_position).normalized()
				var dot_product: float = collider.velocity.dot(push_dir)
				# Only add push if enemy is not already moving away fast enough
				if dot_product < 80.0:
					collider.velocity += push_dir * 200.0



# ==================================================
# BLOCK CALLBACKS
# ==================================================

func _on_block_started() -> void:

	state = State.BLOCK

	velocity = Vector2.ZERO

	last_direction = movement.get_last_dir()



func _on_block_ended() -> void:

	if state == State.BLOCK:

		state = State.IDLE



# ==================================================
# ANIMATION
# ==================================================

func _update_animation() -> void:


	if not animator:

		return



	# Never override attack animation
	if state == State.ATTACK:

		return



	var direction: String = animator.get_dir_from_vector(
		last_direction
	)



	match state:


		State.IDLE:

			animator.play_idle(
				direction
			)


		State.WALK:

			animator.play_walk(
				direction
			)


		State.RUN:

			animator.play_run(
				direction


			)


		State.HURT:

			pass


		State.DEAD:

			pass


		State.DASH:

			animator.play_dash(
				direction
			)


		State.BLOCK:

			if block_comp and block_comp.get_is_blocking():

				animator.play_block(
					direction
				)


		State.SQUAT:

			animator.play_squat(
				direction
			)


		State.JUMP:

			animator.play_jump(
				direction
			)





# ==================================================
# PUBLIC FUNCTIONS
# ==================================================

func set_player_paused(paused: bool) -> void:


	input_enabled = not paused



	if movement:

		movement.set_input_enabled(
			not paused
		)



	if paused:

		velocity = Vector2.ZERO





func set_speed_modifier(mod: float) -> void:


	if movement:

		movement.set_speed_modifier(
			mod
		)
