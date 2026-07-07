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


# ==================================================
# COMPONENT REFERENCES
# ==================================================

@onready var movement: MovementComponent = $MovementComponent

@onready var animator: PlayerAnimationComponent = $PlayerAnimationComponent

@onready var attack: AttackComponent = $AttackComponent

@onready var health: HealthComponent = $HealthComponent

@onready var stamina: StaminaComponent = $StaminaComponent



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
	DEAD
}


var state: State = State.IDLE

var last_direction: Vector2 = Vector2.DOWN

var input_enabled: bool = true



# ==================================================
# READY
# ==================================================

func _ready() -> void:


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



	# Attack and hurt override movement
	if state != State.ATTACK and state != State.HURT:

		_process_movement()

	else:

		velocity = Vector2.ZERO



	move_and_slide()



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

	velocity = Vector2.ZERO



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
