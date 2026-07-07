class_name MovementComponent
extends Component


## Handles player movement input and velocity calculation.
## Sends movement updates to animation components.
## Also manages special movement states: DASH, JUMP, SQUAT.



signal direction_changed(direction: Vector2)

signal movement_state_changed(state: MoveState)



@export_category("Movement Settings")


@export var walk_speed: float = 80.0

@export var run_speed: float = 140.0

## Multiplier applied when dashing (base speed × dash_mult).
@export var dash_mult: float = 2.5

## Multiplier applied when jumping/lunging.
@export var jump_mult: float = 1.5

## Duration (seconds) of a dash before returning to normal movement.
@export var dash_duration: float = 0.3

## Duration (seconds) of a jump lunge.
@export var jump_duration: float = 0.2


@export var analog_walk_threshold: float = 0.18

@export var analog_run_threshold: float = 0.72





var current_speed_mod: float = 1.0


var input_strength: float = 0.0


var input_dir: Vector2 = Vector2.ZERO


var last_dir: Vector2 = Vector2.DOWN


var input_enabled: bool = true

## Direction this entity is dashing / jumping toward.
var special_dir: Vector2 = Vector2.ZERO





enum MoveState
{
	IDLE,
	WALK,
	RUN,
	DASH,
	JUMP,
	SQUAT
}


var move_state: MoveState = MoveState.IDLE:
	set(value):

		if move_state != value:

			move_state = value

			movement_state_changed.emit(
				move_state
			)





# ==================================================
# SPEED
# ==================================================

func set_speed_modifier(
	mod: float
) -> void:


	current_speed_mod = mod





# ==================================================
# INPUT
# ==================================================

func read_input() -> void:


	# Don't override special states (DASH, JUMP, SQUAT) with normal movement.
	if move_state == MoveState.DASH or move_state == MoveState.JUMP or move_state == MoveState.SQUAT:

		return


	if not input_enabled:

		input_dir = Vector2.ZERO

		move_state = MoveState.IDLE

		return



	input_dir = _read_movement_input()



	if input_dir.length() > 1.0:

		input_dir = input_dir.normalized()



	input_strength = clampf(
		input_dir.length(),
		0.0,
		1.0
	)



	if input_dir != Vector2.ZERO:


		var new_direction := input_dir.normalized()



		if new_direction != last_dir:

			last_dir = new_direction


			direction_changed.emit(
				last_dir
			)





# ==================================================
# VELOCITY
# ==================================================

func calculate_velocity() -> Vector2:


	match move_state:

		MoveState.DASH:

			return special_dir * run_speed * dash_mult * current_speed_mod

		MoveState.JUMP:

			return special_dir * run_speed * jump_mult * current_speed_mod

		MoveState.SQUAT:

			return Vector2.ZERO


	if input_dir == Vector2.ZERO or not input_enabled:


		move_state = MoveState.IDLE


		return Vector2.ZERO





	var joystick := _get_joystick()



	var using_joystick := (
		joystick != null
		and joystick.is_active()
		and joystick.strength > 0
	)





	if using_joystick:


		if input_strength >= analog_run_threshold:

			move_state = MoveState.RUN


		else:

			move_state = MoveState.WALK





		var analog_speed := lerpf(
			walk_speed * 0.35,
			run_speed,
			input_strength
		)



		return (
			input_dir.normalized()
			*
			analog_speed
			*
			current_speed_mod
		)





	var running := Input.is_action_pressed(
		"run"
	)



	if running:

		move_state = MoveState.RUN

	else:

		move_state = MoveState.WALK





	var speed := (
		run_speed
		if running
		else walk_speed
	)



	return (
		input_dir
		*
		speed
		*
		current_speed_mod
	)





# ==================================================
# PUBLIC
# ==================================================

func get_last_dir() -> Vector2:


	return last_dir





func set_input_enabled(
	enabled: bool
) -> void:


	input_enabled = enabled



	if not enabled:

		input_dir = Vector2.ZERO




# ==================================================
# SPECIAL MOVEMENT STATES
# ==================================================

## Start a dash in the given direction.
func start_dash(dir: Vector2) -> void:

	special_dir = dir

	move_state = MoveState.DASH


## Start a jump/lunge in the given direction.
func start_jump(dir: Vector2) -> void:

	special_dir = dir

	move_state = MoveState.JUMP


## Toggle squat state on/off.
func start_squat() -> void:

	move_state = MoveState.SQUAT


## Return to IDLE from any special movement state.
func end_special() -> void:

	move_state = MoveState.IDLE


## Returns true if currently in a special movement state.
func is_in_special_state() -> bool:

	return (
		move_state == MoveState.DASH
		or move_state == MoveState.JUMP
		or move_state == MoveState.SQUAT
	)



# ==================================================
# INPUT SOURCES
# ==================================================

func _read_movement_input() -> Vector2:


	var joystick := _get_joystick()



	if joystick != null and joystick.is_active():


		return (
			joystick.direction
			*
			joystick.strength
		)





	return Vector2(
		Input.get_action_strength("right")
		-
		Input.get_action_strength("left"),


		Input.get_action_strength("down")
		-
		Input.get_action_strength("up")
	)





func _get_joystick() -> MobileJoystick:


	var root := get_tree().root



	if root == null:

		return null



	return root.get_node_or_null(
		"virtual_joystick"
	) as MobileJoystick
