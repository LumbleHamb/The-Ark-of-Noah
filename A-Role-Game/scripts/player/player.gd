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


# ==================================================
# STATE
# ==================================================

enum State
{
	IDLE,
	WALK,
	RUN,
	SPRINT,
	ATTACK,
	DEAD,
	DASH,
	ROLL
}


var state: State = State.IDLE

var last_direction: Vector2 = Vector2.DOWN

var input_enabled: bool = true


# ==================================================
# ATTACK COMBO
# ==================================================

var combo_step: int = 0

var combo_timer: float = 0.0

const COMBO_WINDOW: float = 0.6


# ==================================================
# BACKDASH
# ==================================================

var previous_direction: Vector2 = Vector2.DOWN

var direction_switch_timer: float = 999.0

const BACKDASH_WINDOW: float = 0.3



# ==================================================
# READY
# ==================================================

func _ready() -> void:

	# Set FLOATING motion mode for top-down physics (better push behavior)
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING


	if attack:

		attack.attack_started.connect(
			_on_attack_started
		)


	if animator:

		animator.attack_animation_finished.connect(
			_on_attack_animation_finished
		)


	# Connect to the animated sprite directly to handle dash/roll/walktorun end
	var anim_sprite: AnimatedSprite2D = $player_animation

	if anim_sprite and not anim_sprite.animation_finished.is_connected(
		_on_player_animation_finished
	):

		anim_sprite.animation_finished.connect(
			_on_player_animation_finished
		)



	if health:

		health.damaged.connect(
			_on_damaged
		)

		health.died.connect(
			_on_died
		)



	# Block component removed


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



	# Attack, dash, and roll override movement input.
	# Attack zeros velocity (no movement during attack).
	# Dash/roll preserve their own velocity set by movement.calculate_velocity().
	var overrides_movement: bool = (
		state == State.ATTACK
		or state == State.DASH
		or state == State.ROLL
	)

	if not overrides_movement:

		_process_movement()



	if state == State.ATTACK:

		velocity = Vector2.ZERO



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

		var new_dir: Vector2 = movement.input_dir.normalized()

		if new_dir != last_direction:

			previous_direction = last_direction

			direction_switch_timer = 0.0

		last_direction = new_dir



	velocity = movement.calculate_velocity()



	match movement.move_state:


		MovementComponent.MoveState.IDLE:

			state = State.IDLE


		MovementComponent.MoveState.WALK:

			state = State.WALK


		MovementComponent.MoveState.RUN:

			state = State.RUN


		MovementComponent.MoveState.SPRINT:

			state = State.SPRINT





# ==================================================
# PROCESS (combo timer, direction switch timer)
# ==================================================

func _process(delta: float) -> void:

	# Only count combo timer outside of attack state
	# During attack, combo is tracked via the buffered input system
	if combo_step > 0 and state != State.ATTACK:

		combo_timer += delta

		if combo_timer > COMBO_WINDOW:

			_reset_combo()


	if direction_switch_timer < BACKDASH_WINDOW:

		direction_switch_timer += delta



# ==================================================
# INPUT
# ==================================================

var combo_buffered: bool = false

func _process_input() -> void:


	if Input.is_action_just_pressed("attack"):

		if state == State.ATTACK:

			# Buffer the combo input — will advance when current attack animation finishes
			combo_buffered = true

		elif combo_step > 0 and combo_timer < COMBO_WINDOW:

			_advance_combo()

		else:

			_start_attack()


	if Input.is_action_just_pressed("dash"):

		_start_dash()


	if Input.is_action_just_pressed("roll"):

		_start_roll()


	# Block, squat, and jump removed





# ==================================================
# ATTACK
# ==================================================

func _start_attack() -> void:


	if not attack:

		return



	if not attack.can_attack():

		return



	state = State.ATTACK

	# Don't zero velocity — let player slide naturally during attack
	combo_step = 1

	combo_timer = 0.0



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


func _advance_combo() -> void:


	if not attack:

		return



	combo_step += 1

	combo_timer = 0.0



	if combo_step > 3:

		combo_step = 1



	var direction: String = "S"

	if animator:

		direction = animator.get_dir_from_vector(
			last_direction
		)



	state = State.ATTACK

	# Don't zero velocity — let player slide during combo



	match combo_step:

		2:

			animator.play_attack2(direction)

			attack.start_attack_forced(direction)

		3:

			animator.play_attack3(direction)

			attack.start_attack_forced(direction)

			combo_step = 0  # Reset after final hit

		_:

			# Shouldn't happen, but fallback
			combo_step = 1

			animator.play_attack(direction)

			attack.start_attack_forced(direction)


func _reset_combo() -> void:

	combo_step = 0

	combo_timer = 0.0



func _cancel_attack_state() -> void:


	if attack:

		attack.end_attack()


	if animator:

		animator.cancel_attack()


	combo_step = 0

	combo_timer = 0.0

	combo_buffered = false



func _start_dash() -> void:


	if not movement:

		return


	if state == State.DASH or state == State.ROLL or state == State.DEAD:

		return


	# Can interrupt attack with a dash
	if state == State.ATTACK:

		_cancel_attack_state()


	state = State.DASH


	# Backdash check: if player recently changed direction, dash backward instead
	if direction_switch_timer < BACKDASH_WINDOW and previous_direction != Vector2.ZERO:

		movement.start_backdash(previous_direction)

		if animator:

			animator.play_backdash(
				animator.get_dir_from_vector(previous_direction)
			)

	else:

		movement.start_dash(last_direction)

		if animator:

			animator.play_dash(
				animator.get_dir_from_vector(last_direction)
			)


	velocity = movement.calculate_velocity()


	# Dash duration is frame-dependent; animation_finished signal handles ending it


func _start_roll() -> void:


	if not movement:

		return


	if state == State.DASH or state == State.ROLL or state == State.DEAD:

		return


	# Can interrupt attack with a roll
	if state == State.ATTACK:

		_cancel_attack_state()


	state = State.ROLL

	movement.start_roll(last_direction)

	velocity = movement.calculate_velocity()


	if animator:

		animator.play_roll(
			animator.get_dir_from_vector(last_direction)
		)


	# Roll duration is frame-dependent; animation_finished signal handles ending it



# Block, squat, and jump removed





func _on_player_animation_finished() -> void:

	# Handle dash/roll end — these are frame-dependent, not timer-based
	if state == State.DASH:

		state = State.IDLE

		if movement:

			movement.end_special()


	elif state == State.ROLL:

		state = State.IDLE

		if movement:

			movement.end_special()


	# Walktorun is handled by the animation component's play_run detection
	# ATTACK is handled by attack_animation_finished signal


func _on_attack_started(direction: String) -> void:


	# Don't override combo attack animations (attack2/attack3 handled by _advance_combo)
	if combo_step > 0:

		return



	if animator:

		animator.play_attack(
			direction
		)





func _on_attack_animation_finished(completed_combo_step: int) -> void:

	# End the attack component's attack state
	if attack:

		attack.end_attack()


	# If combo was buffered during this attack animation, advance immediately
	if combo_buffered and completed_combo_step < 3:

		combo_buffered = false

		_advance_combo()

		return


	# No further combo — return to idle
	combo_step = 0

	combo_timer = 0.0

	state = State.IDLE





# ==================================================
# DAMAGE
# ==================================================

func _is_invincible_frame() -> bool:


	# Always invincible when dead
	if state == State.DEAD:

		return true


	# Only dash/roll/backdash have invincibility windows
	if state != State.DASH and state != State.ROLL:

		return false


	var anim_sprite: AnimatedSprite2D = $player_animation

	if not anim_sprite or not anim_sprite.is_playing():

		return false


	var anim_name: String = anim_sprite.animation

	if not anim_name.begins_with("dash_") and not anim_name.begins_with("roll_") and not anim_name.begins_with("backdash_"):

		return false


	var total_frames: int = anim_sprite.sprite_frames.get_frame_count(

		anim_name
	)

	var half_frames: int = total_frames / 2


	# First half of the animation = invincible
	return anim_sprite.frame < half_frames



func _on_damaged(
	_amount: int,
	_remaining: int
) -> void:


	if _is_invincible_frame():

		return

	# Hurt animation removed — player uses visual hit indicator later
	# For now, just let the player continue whatever they were doing





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



# Block callbacks removed


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


		State.SPRINT:

			animator.play_sprint(
				direction
			)


		State.DEAD:

			pass


		# DASH and ROLL are handled by the animation component's
		# _on_movement_state_changed signal handler, not here.
		# This avoids re-starting their animations every physics frame.

		# Block removed





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
