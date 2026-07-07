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


@export_category("References")

@export var anim_sprite: AnimatedSprite2D = null


@export_category("Sprite Offsets")

@export var base_offset: Vector2 = Vector2(-32, -43)

@export var attack_offset: Vector2 = Vector2(-48, -59)



var movement: MovementComponent = null


var current_direction: String = "S"


var is_attacking: bool = false

var is_hurt: bool = false

var is_dead: bool = false



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


	if is_attacking or is_hurt or is_dead:

		return



	match state:


		MovementComponent.MoveState.IDLE:

			play_idle(current_direction)



		MovementComponent.MoveState.WALK:

			play_walk(current_direction)



		MovementComponent.MoveState.RUN:

			play_run(current_direction)





func _on_direction_changed(
	direction: Vector2
) -> void:


	current_direction = get_dir_from_vector(
		direction
	)



	if not is_attacking and not is_hurt and not is_dead:

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


	anim_sprite.play(
		"attack_" + dir_key
	)



	if not anim_sprite.animation_finished.is_connected(
		_on_attack_finished
	):

		anim_sprite.animation_finished.connect(
			_on_attack_finished
		)





func _on_attack_finished() -> void:


	is_attacking = false


	if is_dead or is_hurt:

		return



	anim_sprite.offset = base_offset


	_update_current_animation()





func play_hurt(dir_key: String = "") -> void:


	if not anim_sprite:

		return



	is_hurt = true



	if dir_key != "":

		current_direction = dir_key



	anim_sprite.offset = base_offset


	anim_sprite.play(
		"hurt_" + current_direction
	)





func finish_hurt() -> void:


	is_hurt = false


	if not is_attacking and not is_dead:

		_update_current_animation()





func play_death(dir_key: String = "") -> void:


	if not anim_sprite:

		return



	is_dead = true


	if dir_key != "":

		current_direction = dir_key



	anim_sprite.offset = base_offset


	anim_sprite.play(
		"death_" + current_direction
	)





# ==================================================
# BASIC ANIMATIONS
# ==================================================

func play_idle(dir_key: String) -> void:


	if not anim_sprite:

		return



	anim_sprite.offset = base_offset


	_play_if_changed(
		"idle_" + dir_key
	)





func play_walk(dir_key: String) -> void:


	if not anim_sprite:

		return



	anim_sprite.offset = base_offset


	_play_if_changed(
		"walk_" + dir_key
	)





func play_run(dir_key: String) -> void:


	if not anim_sprite:

		return



	anim_sprite.offset = base_offset


	_play_if_changed(
		"run_" + dir_key
	)





func _play_if_changed(animation_name: String) -> void:


	if anim_sprite.animation != animation_name:

		anim_sprite.play(
			animation_name
		)





# ==================================================
# HELPERS
# ==================================================

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
