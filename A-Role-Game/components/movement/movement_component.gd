class_name MovementComponent
extends Component

## Handles player movement input and velocity calculation.
## Reads from keyboard and virtual joystick input.

@export var walk_speed: float = 80.0
@export var run_speed: float = 140.0
@export var analog_walk_threshold: float = 0.18
@export var analog_run_threshold: float = 0.72

var current_speed_mod: float = 1.0
var input_strength: float = 0.0
var input_dir: Vector2 = Vector2.ZERO
var last_dir: Vector2 = Vector2.DOWN
var input_enabled: bool = true

enum MoveState { IDLE, WALK, RUN }
var move_state: MoveState = MoveState.IDLE

## Sets a speed multiplier for all movement calculations.
func set_speed_modifier(mod: float) -> void:
	current_speed_mod = mod

## Reads input from joystick or keyboard and updates input_dir.
func read_input() -> void:
	if not input_enabled:
		input_dir = Vector2.ZERO
		move_state = MoveState.IDLE
		return
	input_dir = _read_movement_input()
	if input_dir.length() > 1.0:
		input_dir = input_dir.normalized()
	input_strength = clampf(input_dir.length(), 0.0, 1.0)
	if input_dir != Vector2.ZERO:
		last_dir = input_dir.normalized()

## Returns velocity based on input direction and walk/run speed.
func calculate_velocity() -> Vector2:
	if input_dir == Vector2.ZERO or not input_enabled:
		move_state = MoveState.IDLE
		return Vector2.ZERO
	var js: MobileJoystick = _get_joystick()
	var has_analog_joystick: bool = js != null and js.is_active() and js.strength > 0.0
	if has_analog_joystick:
		if input_strength >= analog_run_threshold:
			move_state = MoveState.RUN
		elif input_strength >= analog_walk_threshold:
			move_state = MoveState.WALK
		else:
			move_state = MoveState.WALK
		var analog_speed: float = lerpf(walk_speed * 0.35, run_speed, input_strength)
		return input_dir.normalized() * analog_speed * current_speed_mod
	var running: bool = Input.is_action_pressed("run")
	move_state = MoveState.RUN if running else MoveState.WALK
	var speed: float = run_speed if running else walk_speed
	return input_dir * speed * current_speed_mod

func get_last_dir() -> Vector2:
	return last_dir

## Enables or disables input. Resets input_dir when disabled.
func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled
	if not enabled:
		input_dir = Vector2.ZERO

func _read_movement_input() -> Vector2:
	var js: MobileJoystick = _get_joystick()
	if js != null and js.is_active() and js.strength > 0.0:
		return js.direction * js.strength
	var v: Vector2 = Vector2(
		Input.get_action_strength("right") - Input.get_action_strength("left"),
		Input.get_action_strength("down") - Input.get_action_strength("up")
	)
	if v.length() > 1.0:
		v = v.normalized()
	return v

func _get_joystick() -> MobileJoystick:
	var root: Node = get_tree().root if get_tree() else null
	if root == null:
		return null
	return root.get_node_or_null("virtual_joystick") as MobileJoystick
