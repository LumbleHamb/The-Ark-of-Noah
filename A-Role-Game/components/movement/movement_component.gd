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

## Speed when sprinting (faster than run_speed).
@export var sprint_speed: float = 220.0

## Forward dash speed.
@export var dash_speed: float = 350.0

## Backward dash speed (often slower than forward dash).
@export var backdash_speed: float = 280.0

## Speed when rolling.
@export var roll_speed: float = 180.0


@export var analog_walk_threshold: float = 0.18

@export var analog_run_threshold: float = 0.72




var current_speed_mod: float = 1.0


var input_strength: float = 0.0


var input_dir: Vector2 = Vector2.ZERO


var last_dir: Vector2 = Vector2.DOWN


var input_enabled: bool = true

## Direction this entity is dashing / jumping toward.
var special_dir: Vector2 = Vector2.ZERO

## True when the current DASH state is a backdash (uses backdash_speed + backdash animation).
var is_backdash: bool = false




enum MoveState
{
	IDLE,
	WALK,
	RUN,
	SPRINT,
	DASH,
	ROLL,
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
	if move_state == MoveState.DASH or move_state == MoveState.ROLL:

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

			var dash_spd: float = backdash_speed if is_backdash else dash_speed

			return special_dir * dash_spd * current_speed_mod

		MoveState.ROLL:

			return special_dir * roll_speed * current_speed_mod

		# JUMP and SQUAT removed


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


		var joystick_sprint := Input.is_action_pressed("sprint")



		if joystick_sprint and input_strength >= analog_run_threshold:


			move_state = MoveState.SPRINT



		elif input_strength >= analog_run_threshold:


			move_state = MoveState.RUN



		else:


			move_state = MoveState.WALK




		var spd: float = (


			sprint_speed


			if move_state == MoveState.SPRINT


			else lerpf(walk_speed * 0.35, run_speed, input_strength)


		)


		return (


			input_dir.normalized()


			*


			spd


			*


			current_speed_mod


		)


	var running := Input.is_action_pressed(
		"run"
	)

	var sprinting := Input.is_action_pressed(
		"sprint"
	)



	if running and sprinting:

		move_state = MoveState.SPRINT

	elif running:

		move_state = MoveState.RUN

	else:

		move_state = MoveState.WALK




	var speed := (
		sprint_speed
		if move_state == MoveState.SPRINT
		else (
			run_speed
			if running
			else walk_speed
		)
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

## Start a forward dash in the given direction.
func start_dash(dir: Vector2) -> void:

	is_backdash = false

	special_dir = dir

	move_state = MoveState.DASH


## Start a backward dash (backdash) in the given direction.
func start_backdash(dir: Vector2) -> void:

	is_backdash = true

	special_dir = dir

	move_state = MoveState.DASH


## Start a roll in the given direction.
func start_roll(dir: Vector2) -> void:

	special_dir = dir

	move_state = MoveState.ROLL


## Return to IDLE from any special movement state.
func end_special() -> void:

	is_backdash = false

	move_state = MoveState.IDLE


## Returns true if currently in a special movement state.
func is_in_special_state() -> bool:

	return (
		move_state == MoveState.DASH
		or move_state == MoveState.ROLL
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
