class_name PlayerAnimationComponent
extends Component

## Controls player animation states and direction.
## Works with MovementComponent and AttackComponent.
##
## Animation naming format:
## idle_N
## walk_SE
## run_W
## attack_NE

## Emitted when an attack animation (attack/attack2/attack3) finishes playing all frames.
signal attack_animation_finished(combo_step: int)


@export_category("References")

@export var anim_sprite: AnimatedSprite2D = null


@export_category("Sprite Offsets")

@export var base_offset: Vector2 = Vector2(-64, -86)

@export var attack_offset: Vector2 = Vector2(-64, -86)

@export var dash_offset: Vector2 = Vector2(-64, -86)

@export var block_offset: Vector2 = Vector2(-64, -86)



var movement: MovementComponent = null


var current_direction: String = "S"


var is_attacking: bool = false

var is_dead: bool = false

# Set to true when walk→run transition plays walktorun instead of run.
# Cleared when walktorun animation finishes and run actually plays.
var _walktorun_pending: bool = false

# Set to true when run→walk transition plays walktorun in reverse (runtowalk).
# Cleared when the reversed walktorun animation finishes.
var _runtowalk_pending: bool = false



# ==================================================
# COMPONENT READY
# ==================================================

func _component_ready() -> void:


	if not anim_sprite:

		anim_sprite = get_entity().get_node_or_null(
			"player_animation"
		) as AnimatedSprite2D



	movement = get_sibling_component(
		MovementComponent
	) as MovementComponent



	if anim_sprite:

		anim_sprite.offset = base_offset

		# Connect once instead of per-call
		if not anim_sprite.animation_finished.is_connected(
			_on_any_animation_finished
		):

			anim_sprite.animation_finished.connect(
				_on_any_animation_finished
			)



	if movement:

		movement.direction_changed.connect(
			_on_direction_changed
		)

		movement.movement_state_changed.connect(
			_on_movement_state_changed
		)



# ==================================================
# SETUP
# ==================================================

func setup(sprite: AnimatedSprite2D) -> void:


	anim_sprite = sprite


	if anim_sprite:

		anim_sprite.offset = base_offset



# ==================================================
# MOVEMENT ANIMATIONS
# ==================================================

func _on_movement_state_changed(
	state: MovementComponent.MoveState
) -> void:


	if is_attacking or is_dead:

		return



	match state:


		MovementComponent.MoveState.IDLE:

			play_idle(current_direction)



		MovementComponent.MoveState.WALK:

			play_walk(current_direction)



		MovementComponent.MoveState.RUN:

			play_run(current_direction)



		MovementComponent.MoveState.SPRINT:

			play_sprint(current_direction)



		MovementComponent.MoveState.DASH:

			if movement and movement.is_backdash:

				play_backdash(current_direction)

			else:

				play_dash(current_direction)


		MovementComponent.MoveState.ROLL:

			play_roll(current_direction)




func _on_direction_changed(
	direction: Vector2
) -> void:


	current_direction = get_dir_from_vector(
		direction
	)



	if not is_attacking and not is_dead:

		_update_current_animation()




func _update_current_animation() -> void:


	if not movement:

		return



	match movement.move_state:


		MovementComponent.MoveState.IDLE:

			play_idle(current_direction)



		MovementComponent.MoveState.WALK:

			play_walk(current_direction)



		MovementComponent.MoveState.RUN:

			play_run(current_direction)



		MovementComponent.MoveState.SPRINT:

			play_sprint(current_direction)



		MovementComponent.MoveState.DASH:

			if movement and movement.is_backdash:

				play_backdash(current_direction)

			else:

				play_dash(current_direction)



		MovementComponent.MoveState.ROLL:

			play_roll(current_direction)



# ==================================================
# PUBLIC ACTION ANIMATIONS
# ==================================================

func play_attack(dir_key: String) -> void:


	if not anim_sprite:

		return



	is_attacking = true


	current_direction = dir_key


	anim_sprite.offset = attack_offset


	anim_sprite.stop()

	anim_sprite.frame = 0


	anim_sprite.speed_scale = 1.0

	anim_sprite.play(
		"attack_" + dir_key
	)
func play_attack2(dir_key: String) -> void:


	if not anim_sprite:

		return



	is_attacking = true


	current_direction = dir_key


	anim_sprite.offset = attack_offset


	anim_sprite.stop()

	anim_sprite.frame = 0


	anim_sprite.speed_scale = 1.0

	anim_sprite.play(
		"attack2_" + dir_key
	)



func play_attack3(dir_key: String) -> void:


	if not anim_sprite:

		return



	is_attacking = true


	current_direction = dir_key


	anim_sprite.offset = attack_offset


	anim_sprite.stop()

	anim_sprite.frame = 0


	anim_sprite.speed_scale = 1.0

	anim_sprite.play(
		"attack3_" + dir_key
	)



func cancel_attack() -> void:


	is_attacking = false


	if anim_sprite:

		anim_sprite.offset = base_offset



func _on_any_animation_finished() -> void:


	if not anim_sprite:

		return


	var anim_name: String = anim_sprite.animation


	# Handle attack animation finishes — emit signal for attack combo
	if anim_name.begins_with("attack"):

		is_attacking = false

		anim_sprite.offset = base_offset

		attack_animation_finished.emit(_combo_step_from_name(anim_name))

		return


	# Handle walktorun -> run transition (forward) or runtowalk (reverse)
	if anim_name.begins_with("walktorun"):

		anim_sprite.speed_scale = 1.0

		if _runtowalk_pending:

			_runtowalk_pending = false

			if movement:

				_update_current_animation()

			return


		_walktorun_pending = false

		if movement:

			match movement.move_state:

				MovementComponent.MoveState.RUN:

					play_run(current_direction)

				_:

					_update_current_animation()

		return


	# For one-shot action animations (dash, roll, backdash), just restore offset.
	# The player's own animation_finished handler will end those states.
	anim_sprite.offset = base_offset


func _combo_step_from_name(anim_name: String) -> int:

	if anim_name.begins_with("attack2"):

		return 2

	if anim_name.begins_with("attack3"):

		return 3

	return 1


func play_walktorun(dir_key: String) -> void:


	if not anim_sprite:

		return



	anim_sprite.offset = base_offset


	_play_if_changed(
		"walktorun_" + dir_key
	)



func play_runtowalk(dir_key: String) -> void:


	if not anim_sprite:

		return



	anim_sprite.offset = base_offset


	var anim_name: String = "walktorun_" + dir_key

	if not _has_animation(anim_name):

		anim_name = "walktorun_E"


	var frame_count: int = anim_sprite.sprite_frames.get_frame_count(anim_name) - 1


	anim_sprite.frame = frame_count

	anim_sprite.speed_scale = -1.0

	anim_sprite.play()



func play_dash(dir_key: String) -> void:


	if not anim_sprite:

		return



	anim_sprite.offset = dash_offset


	var final_dir: String = dir_key

	if not _has_animation("dash_" + dir_key):

		final_dir = "E" if dir_key in ["E", "SE", "NE"] else "W"


	_play_if_changed(

		"dash_" + final_dir

	)



func play_roll(dir_key: String) -> void:


	if not anim_sprite:

		return



	anim_sprite.offset = dash_offset


	var final_dir: String = dir_key

	if not _has_animation("roll_" + dir_key):

		final_dir = "E" if dir_key in ["E", "SE", "NE"] else "W"


	_play_if_changed(

		"roll_" + final_dir

	)



func play_backdash(dir_key: String) -> void:


	if not anim_sprite:

		return



	anim_sprite.offset = dash_offset


	var final_dir: String = dir_key

	if not _has_animation("backdash_" + dir_key):

		final_dir = "E" if dir_key in ["E", "SE", "NE"] else "W"



	_play_if_changed(

		"backdash_" + final_dir

	)



func play_block(dir_key: String) -> void:


	if not anim_sprite:

		return



	anim_sprite.offset = block_offset


	_play_if_changed(
		"block_" + dir_key
	)



func _play_if_changed(animation_name: String) -> void:


	if anim_sprite.animation != animation_name:

		anim_sprite.speed_scale = 1.0

		anim_sprite.play(
			animation_name
		)




# ==================================================
# HELPERS
# ==================================================

func _has_animation(anim_name: String) -> bool:


	if not anim_sprite:

		return false



	return anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation(anim_name)




func _fallback_dir(dir_key: String) -> String:


	if _has_animation("dash_" + dir_key):

		return dir_key


	return "E" if dir_key in ["E", "SE", "NE"] else "W"


func stop_animation() -> void:


	if anim_sprite:

		anim_sprite.stop()




func is_playing() -> bool:


	return (
		anim_sprite != null
		and anim_sprite.is_playing()
	)




func get_dir_from_vector(v: Vector2) -> String:


	if v == Vector2.ZERO:

		return "S"



	var angle: float = rad_to_deg(
		atan2(
			v.y,
			v.x
		)
	)



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


# ==================================================
# BASIC ANIMATIONS
# ==================================================

func play_idle(dir_key: String) -> void:


	if not anim_sprite:

		return


	_walktorun_pending = false

	_runtowalk_pending = false

	anim_sprite.speed_scale = 1.0


	anim_sprite.offset = base_offset


	_play_if_changed(
		"idle_" + dir_key
	)




func play_walk(dir_key: String) -> void:


	if not anim_sprite:

		return



	# If walktorun was pending, clear it — shift was released mid-transition
	_walktorun_pending = false


	# If currently playing a run animation, transition through runtowalk first
	var cur: String = anim_sprite.animation

	if not _runtowalk_pending and cur.begins_with("run_"):

		_runtowalk_pending = true

		play_runtowalk(dir_key)

		return


	# If a runtowalk transition is still in progress, don't override it
	if _runtowalk_pending:

		return



	anim_sprite.offset = base_offset


	_play_if_changed(
		"walk_" + dir_key
	)




func play_run(dir_key: String) -> void:


	if not anim_sprite:

		return


	# Cancel any runtowalk transition (shift pressed again during reverse)
	_runtowalk_pending = false

	anim_sprite.speed_scale = 1.0


	# If currently playing a walk animation, transition through walktorun first
	var cur: String = anim_sprite.animation

	if not _walktorun_pending and cur.begins_with("walk_"):

		_walktorun_pending = true

		play_walktorun(dir_key)

		return


	# If a walktorun transition is still in progress, don't override it
	if _walktorun_pending:

		return



	anim_sprite.offset = base_offset


	_play_if_changed(
		"run_" + dir_key
	)



func play_sprint(dir_key: String) -> void:


	if not anim_sprite:

		return


	_walktorun_pending = false

	_runtowalk_pending = false

	anim_sprite.speed_scale = 1.0


	anim_sprite.offset = base_offset


	_play_if_changed(
		"sprint_" + dir_key
	)



func play_death(dir_key: String = "") -> void:


	if not anim_sprite:

		return



	is_dead = true


	if dir_key != "":

		current_direction = dir_key



	anim_sprite.offset = base_offset

	anim_sprite.speed_scale = 1.0

	anim_sprite.play(
		"death_" + current_direction
	)
